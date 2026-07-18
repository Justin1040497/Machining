qmc-decrypt
---
## Supported formats
- `mgg1` and `mflac0` with manually `ekey` passed, to `ogg` and `flac`
  
## Usage
```
Usage: qmc-decrypt <input> <output> [ekey]

Arguments:
  <input>   
  <output>  
  [ekey]    

Options:
  -h, --help  Print help information
```

## See also/references
- https://github.com/unlock-music/cli/issues/37 (archive: https://web.archive.org/web/20221227073117/https://git.unlock-music.dev/um/cli/issues/37)
- https://github.com/jixunmoe/qmc2-rust
- https://github.com/unlock-music/unlock-music/discussions/278
- https://github.com/bczhc/qmc-decode
- https://github.com/zeroclear/unlock-mflac-20220931/issues/1 (archive: https://web.archive.org/web/20221227073855/https://github.com/zeroclear/unlock-mflac-20220931/issues/1)

Thanks to the `qmc2-crypto` module from [jixunmoe](https://github.com/jixunmoe).

## About `ekey`

This project has **no** bundled secrets. Each ekey is attached to the song and should be obtained manually.

<img width="1149" alt="image" src="https://github.com/user-attachments/assets/89be9970-5e6d-4236-b605-0172c135a2ce" />
