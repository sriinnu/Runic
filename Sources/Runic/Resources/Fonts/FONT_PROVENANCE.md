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
- Shippori Mincho: bundled static TTF files (Regular, SemiBold, Bold, ExtraBold) for the Sumi skin's names and numerals, license in `OFL-ShipporiMincho.txt`. Subset with `pyftsubset` to Latin, Latin-1, general punctuation, arrows and the two seal glyphs (印, 注) so the four weights weigh 118 KB each instead of 8.6 MB; the OFL declares no Reserved Font Name, so the subset keeps its names. Addressed by PostScript name in `RunicSumiKit.swift`.
- Zen Kaku Gothic New: bundled static TTF files (Regular, Medium, Bold) for the Sumi skin's labels and body, license in `OFL-ZenKakuGothicNew.txt`. Same Latin subset as Shippori Mincho (32 KB per weight).
- Courier Prime: bundled static TTF files (Regular, Bold) for the Receipt theme — everything printed on the paper and the body's tabs and buttons — from google/fonts `ofl/courierprime`, license in `OFL-CourierPrime.txt` (no Reserved Font Name). Small Latin files (71–73 KB), so bundled unsubset. Addressed by PostScript name (`CourierPrime-Regular`, `CourierPrime-Bold`) in `RunicReceiptKit.swift`.
- B612: bundled static TTF files (Regular, Bold) for the Flight deck skin's body text, license in `OFL-B612.txt`. The Airbus cockpit typeface (Airbus / Intactile Design / Polarsys); the OFL declares no Reserved Font Name. Addressed by PostScript name (`B612-Regular`, `B612-Bold`) in `RunicFlightDeckKit.swift`.
- B612 Mono: bundled static TTF files (Regular, Bold) for the Flight deck skin's tapes, annunciators and readouts, license in `OFL-B612Mono.txt`. Addressed by PostScript name (`B612Mono-Regular`, `B612Mono-Bold`).
- Barlow: bundled static TTF files (Regular, Medium, SemiBold) for the Departures skin's running copy, license in `OFL-Barlow.txt`. Fetched from the google/fonts repository (`ofl/barlow`); ~105 KB per weight, so shipped whole. No Reserved Font Name. Addressed by PostScript name in `RunicDeparturesKit.swift`.
- Barlow Condensed: bundled static TTF files (Regular, Medium, SemiBold, Bold) for the Departures skin's board — flap tiles, caps labels, tabs, buttons, every numeral — license in `OFL-BarlowCondensed.txt`. Fetched from the google/fonts repository (`ofl/barlowcondensed`); ~105 KB per weight, shipped whole. Carries `tnum` for tabular digits. Addressed by PostScript name in `RunicDeparturesKit.swift`.
- Fraunces: bundled static TTF files (Fraunces 9pt Regular/SemiBold/Bold/Black/Italic, SOFT=0 optical) for the Gazette theme's editorial serif — headlines, numerals, the nameplate, and the italic pull quote — from the undercasetype/Fraunces static instances; license in `OFL-Fraunces.txt`. Static rather than variable because variable fonts do not resolve under NSHostingView. The Gazette body face is Manrope; Fraunces is addressed by PostScript name in `RunicGazetteChrome.swift`.

## Local-Only Commercial Fonts

- Berkeley Mono / TX-02: shown in the picker only when installed locally through Font Book.
- Operator Mono: shown in the picker only when installed locally through Font Book.

These commercial fonts are not open-source assets and must not be committed or bundled without redistribution proof.
