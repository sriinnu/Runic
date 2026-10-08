# Font Provenance

Runic only exposes bundled or locally installed families that the app can resolve at runtime. Do not add a font file here unless the project owner has the right to redistribute it in this repository and app bundle.

## Open Font License

- Mona Sans: bundled OTF files, license in `OFL-MonaSans.txt`.
- Commit Mono: bundled OTF files, license in `OFL-CommitMono.txt`.
- Geist and Geist Mono: bundled TTF files, license in `OFL-Geist.txt`.
- VT323: bundled TTF file for Retro decoration, license in `OFL-VT323.txt`.
- Patrick Hand: bundled TTF file for Kirigami titles, license in `OFL-PatrickHand.txt`.
- Nunito: bundled TTF files (Regular, Medium, SemiBold, Bold) for Kirigami body text, license in `OFL-Nunito.txt`.
- JetBrains Mono: bundled TTF files (Regular, Medium, SemiBold, Bold) for the Terminal theme body, license in `OFL-JetBrainsMono.txt`.
- Manrope: bundled TTF files (Regular, Medium, SemiBold, Bold) for the Gazette theme body, license in `OFL-Manrope.txt`.
- Fraunces: bundled static TTF files (Fraunces 9pt Regular/SemiBold/Bold/Black, SOFT=0 optical) for the Gazette theme's editorial serif, from the googlefonts/fraunces static instances; license in `OFL-Fraunces.txt`. Static rather than variable because variable fonts do not resolve under NSHostingView.

## Local-Only Commercial Fonts

- Berkeley Mono / TX-02: shown in the picker only when installed locally through Font Book.
- Operator Mono: shown in the picker only when installed locally through Font Book.

These commercial fonts are not open-source assets and must not be committed or bundled without redistribution proof.
