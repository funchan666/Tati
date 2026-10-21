# Room audience display

The user requested stable, distinct, nonzero counts for each bundled video and voice room. `FoodRoom.initialAudienceCount` is explicit presentation configuration, not a live audience measurement. No randomized refresh, synthetic member accounts, chat messages or microphone occupants are produced by this change.

The room header reads the configured value for both room types. Member details remain unavailable until a real presence service is connected. Replace the display source with authoritative presence counts when integrating that service; do not clamp real zero counts to these values or use these values for rankings or billing.

| Room ID | Initial count |
| --- | ---: |
| pasta-table | 264 |
| street-bites | 486 |
| kitchen-stories | 728 |
| sweet-evening | 193 |
| soup-kitchen | 351 |
| crepe-station | 612 |
| dinner-conversation | 86 |
| dessert-club | 124 |
| market-table | 59 |
| weekend-bbq | 97 |
