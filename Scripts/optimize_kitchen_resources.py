"""Prepare smaller app resources; original supplied media stays in ProjectMaterials.

This does not build or run the app. Keep this pass separate from source import.
PNG optimization is pixel-lossless; JPEG and video use bounded delivery quality.
"""
from pathlib import Path
import json
import os
import hashlib
import subprocess
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT / 'Tati/Resources'
REPORT = ROOT / 'Documentation/Resource-delivery-sizes.json'

def main():
    records = []
    prior = json.loads(REPORT.read_text()) if REPORT.exists() else {}
    prepared = {r.get('deliveryResource', r['resource']): r for r in prior.get('resources', [])}
    for path in sorted(RESOURCES.rglob('*')):
        if not path.is_file() or path.suffix.lower() not in {'.png', '.jpg', '.jpeg', '.mp4'}:
            continue
        before = path.stat().st_size
        relative = str(path.relative_to(RESOURCES))
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if relative in prepared and prepared[relative].get('sha256After') == digest:
            records.append(prepared[relative])
            continue
        temp = path.with_name(path.stem + '.delivery' + path.suffix)
        suffix = path.suffix.lower()
        if suffix == '.mp4':
            subprocess.run(['ffmpeg', '-v', 'error', '-i', str(path), '-map', '0:v:0', '-map', '0:a?',
                            '-c:v', 'libx264', '-preset', 'medium', '-crf', '26', '-pix_fmt', 'yuv420p',
                            '-c:a', 'aac', '-b:a', '96k', '-threads', '4', '-movflags', '+faststart', '-y', str(temp)], check=True)
            original = json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','json',str(path)]))
            delivery = json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','json',str(temp)]))
            assert abs(float(original['format']['duration']) - float(delivery['format']['duration'])) < 0.2
        else:
            with Image.open(path) as image:
                image.load()
                if suffix == '.png':
                    image.save(temp, optimize=True, compress_level=9)
                    with Image.open(temp) as check:
                        assert check.mode == image.mode and check.size == image.size and check.tobytes() == image.tobytes()
                else:
                    upright = ImageOps.exif_transpose(image)
                    upright.save(temp, quality=86, optimize=True, progressive=True, subsampling=0,
                                 icc_profile=image.info.get('icc_profile'))
        if temp.stat().st_size < before:
            os.replace(temp, path)
        else:
            temp.unlink()
        records.append({'resource': relative, 'beforeBytes': before, 'afterBytes': path.stat().st_size,
                        'sha256After': hashlib.sha256(path.read_bytes()).hexdigest()})
        if suffix == '.mp4':
            print(path.name, before, path.stat().st_size, flush=True)
    summary = {'scope': 'App resource source bytes, not an IPA or App Store download estimate',
               'firstPassComparison': prior.get('firstPassComparison', {'beforeBytes': prior.get('beforeBytes'), 'afterBytes': prior.get('afterBytes')}),
               'beforeBytes': sum(r['beforeBytes'] for r in records), 'afterBytes': sum(r['afterBytes'] for r in records),
               'resources': records}
    REPORT.write_text(json.dumps(summary, indent=2) + '\n')
    print('TOTAL', summary['beforeBytes'], summary['afterBytes'], flush=True)

if __name__ == '__main__':
    main()
