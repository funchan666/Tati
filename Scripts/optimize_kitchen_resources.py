"""Losslessly compress bundled PNGs; preserve pixels, sizing and color metadata.

Never recompress JPEGs, fonts or hosted media. Original artwork is untouched.
Requires Pillow and oxipng. Does not build, type-check or run the application.
"""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess
import tempfile
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT / 'Tati/Resources'
REPORT = ROOT / 'Documentation/Resource-delivery-sizes.json'
COLOR_KEYS = ('icc_profile', 'srgb', 'gamma', 'chromaticity', 'cicp')


def appearance(path):
    with Image.open(path) as image:
        image.load()
        assert getattr(image, 'n_frames', 1) == 1, 'Animated image requires a separate review'
        pixels = ImageOps.exif_transpose(image).convert('RGBA')
        return (pixels.size, hashlib.sha256(pixels.tobytes()).hexdigest(),
                {key: image.info.get(key) for key in COLOR_KEYS})


def main():
    optimizer = shutil.which('oxipng')
    if not optimizer:
        raise SystemExit('Install oxipng before running lossless resource compression.')
    total_before = sum(p.stat().st_size for p in RESOURCES.rglob('*') if p.is_file())
    records = []
    with tempfile.TemporaryDirectory(prefix='tati-artwork-') as workspace:
        for index, path in enumerate(sorted(RESOURCES.rglob('*.png'))):
            before = path.stat().st_size
            original = appearance(path)
            temp = Path(workspace) / 'artwork.png'
            # Keep orientation and color-related chunks; remove authoring metadata only.
            with Image.open(path) as image:
                strip = 'tEXt,zTXt,iTXt,tIME'
                if image.getexif().get(274, 1) == 1:
                    strip += ',eXIf'
            subprocess.run([optimizer, '-q', '-o', '4', '-t', '2', '--timeout', '12',
                            '--strip', strip, '--out', str(temp), str(path)], check=True)
            assert appearance(temp) == original, 'Appearance changed: ' + path.name
            changed = temp.stat().st_size < before
            if changed:
                os.replace(temp, path)
            else:
                temp.unlink()
            records.append({'resource': str(path.relative_to(RESOURCES)), 'beforeBytes': before,
                            'afterBytes': path.stat().st_size, 'dimensions': list(original[0]),
                            'decodedRGBA256': original[1], 'pixelsAndColorMetadataUnchanged': True})
            if (index + 1) % 20 == 0:
                print('Verified PNGs:', index + 1, flush=True)
    total_after = sum(p.stat().st_size for p in RESOURCES.rglob('*') if p.is_file())
    report = {'scope': 'Bundled resource source bytes, not a compiled app, IPA or App Store download estimate',
              'method': 'oxipng lossless compression; exact decoded RGBA, dimensions and color metadata compared',
              'originalArtworkModified': False, 'resizingOrLossyReencodingPerformed': False,
              'beforeBytes': total_before, 'afterBytes': total_after,
              'savedBytes': total_before - total_after, 'pngFilesVerified': len(records),
              'buildTestsOrAppRunPerformed': False, 'resources': records}
    REPORT.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({k: v for k, v in report.items() if k != 'resources'}, indent=2))


if __name__ == '__main__':
    main()
