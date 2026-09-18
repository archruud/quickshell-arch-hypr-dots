# 01 — Grunninstallasjon (Base System Setup)

*[English (primary)](base-system-setup.md) — norsk versjon*

## Hva det er

Det aller første scriptet som kjøres på en fersk Arch Linux + Hyprland-installasjon. Slår sammen det som tidligere var to separate steg (`01-base` + `02-post-install`) til ett: pakkeinstallasjon, deretter fiksene som gjør at Dolphin/KDE-programmer oppfører seg riktig under Hyprland.

## Hva det gjør

**Del 1 — Pakker**
- Installerer `yay` (AUR-hjelper) hvis den mangler
- Installerer alle pakker fra `pacman-packages.txt` (systemverktøy, terminal, fonter, filbehandler, media, nettverk, lyd, nettleser, arkivering)
- Installerer alle pakker fra `aur-packages.txt` (zed, kate, libreoffice-fresh-nb, nmgui-bin, osv.)

**Del 2 — Post-install fikser**
1. **Dolphin-terminal** — symlinker `kitty.desktop` til `org.kde.konsole.desktop` og setter `TerminalApplication=kitty` i `kdeglobals`, slik at Dolphins innebygde terminal åpner kitty i stedet for konsole.
2. **XDG-brukermapper** — regenererer `~/Skrivebord`, `~/Nedlastinger` osv. under `nb_NO.UTF-8`-locale, og hvis en tidligere kjøring allerede lagde engelske duplikater (`Downloads` ved siden av `Nedlastinger`), flyttes innholdet inn i den riktig navngitte mappa og den tomme duplikaten fjernes. Overskriver aldri eksisterende filer. **Sikkerhetsmerknad:** sjekker eksplisitt mot at `xdg-user-dir` returnerer `$HOME` selv som fallback når `user-dirs.dirs` ikke finnes ennå (tilfellet på en helt fersk installasjon) — uten denne sjekken kunne hele hjemmemappa blitt feiltolket som en "duplikat" og alt innholdet flyttet inn i én undermappe.
3. **"Open with" i Dolphin** — installerer `archlinux-xdg-menu`, bygger KDE sin service-cache på nytt (`kbuildsycoca6 --noincremental`), og bekrefter at `hl.env("XDG_MENU_PREFIX", "arch-")` finnes i `hyprland.lua`.

Hvis `auto-cpufreq` er blant AUR-pakkene dine: pakkens egen installer sier eksplisitt at tjenesten **ikke** starter av seg selv. Scriptet kjører nå `systemctl enable --now auto-cpufreq` automatisk rett etter at AUR-pakkene er ferdige — ingen manuelt steg nødvendig.

## Innstillinger den trenger for å fungere

- **Locale**: forutsetter at `nb_NO.UTF-8` er generert på systemet (`locale -a` må liste den). Hvis ikke, forteller scriptet deg å legge den til i `/etc/locale.gen` og kjøre `locale-gen` først.
- **`hyprland.lua` må allerede finnes** for at steg 3 skal kunne bekrefte env-variabelen — er du på en helt fersk installasjon, sørg for at monitor/grunnoppsettet er på plass først (eller bare ignorer advarselen og legg til linjen selv).

## Installasjon

```bash
chmod +x install-base-system.sh
./install-base-system.sh
```

Valgfri interaktiv modus (spør før hver pakkegruppe):
```bash
INSTALL_MODE=interaktiv ./install-base-system.sh
```

**Viktig:** logg helt ut av Hyprland og inn igjen etterpå (ikke bare `hyprctl reload`) — `XDG_MENU_PREFIX` og KDE-service-cachen leses kun ved sesjonsstart.

## Filer i denne mappen

```
01-base-system/
├── install-base-system.sh
├── pacman-packages.txt
└── aur-packages.txt
```
