# Sky130 PDK Installation

## Full PDK Installed

The full Sky130 PDK has been installed via volare PDK manager.

**Location:** `/root/.volare/sky130A/`
**Version:** `c6d73a35f524070e85faff4a6a9eef49553ebc2b`
**Size:** 1.1 GB
**Installed:** 2025-12-18

## What Changed

**Before:**
- Stub libraries: 53KB total
- Liberty files: 1.7-7.5KB (incomplete)
- LEF files: 2.1-2.8KB (incomplete)

**After:**
- Full PDK: 1.1GB total
- Liberty files: 13MB each (complete with timing/power data)
- LEF files: 1.4MB (complete physical layouts)
- Via definitions: Complete
- Power/ground pins: Complete

## Directory Structure

```
pdk/sky130A/ -> /root/.volare/sky130A/
  ├── libs.ref/
  │   ├── sky130_fd_sc_hd/
  │   │   ├── lib/          # Liberty timing files (.lib)
  │   │   ├── lef/          # Physical layout files (.lef)
  │   │   └── ...
  │   └── ...
  └── libs.tech/            # Technology files
```

## Backup

Old stub files backed up to: `sky130A_stubs_backup/`

## Usage

The synthesis and place & route scripts will now use the full PDK automatically.

No changes to scripts required - paths remain the same.
