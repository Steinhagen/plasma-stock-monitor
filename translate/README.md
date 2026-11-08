# Translations

The widget is translated with [GNU gettext](https://www.gnu.org/software/gettext/)
through [Ki18n](https://api.kde.org/ki18n-index.html). Every user-visible string in
the QML sources is wrapped in `i18n()` (or `i18nc()` / `i18np()` when it needs a
context or a plural form), and the compiled catalogs are shipped inside the package.

Romanian (`ro`) is the first language and is complete.

## How Plasma finds the strings

Plasma derives the translation domain from the applet id in `metadata.json`:

```
plasma_applet_io.github.steinhagen.plasmastockmonitor
```

and registers `<package>/contents/locale` as the domain's locale directory
(`Plasma::PluginLoader` → `KLocalizedString::addDomainLocaleDir()`, with the package
path `translations` defined as `contents/locale`). The compiled catalogs must
therefore live at:

```
contents/locale/<language>/LC_MESSAGES/plasma_applet_io.github.steinhagen.plasmastockmonitor.mo
```

The widget name and description shown in the "Add Widgets" dialog are not part of
the gettext catalog: they are translated inline in `metadata.json` with the
`Name[<language>]` and `Description[<language>]` keys.

## Files

| File | Purpose |
| --- | --- |
| `template.pot` | Extracted messages: the source of truth for translators. |
| `<language>.po` | One catalog per language; `ro.po` is the Romanian one. |
| `merge.sh` | Re-extracts `template.pot` and merges changes into every `.po`. |
| `build.sh` | Compiles every `.po` into `contents/locale/<language>/…/*.mo`. |

The `.mo` files are committed because the widget is installed straight from this
tree (there is no build step that would generate them), so a fresh checkout and a
released `.plasmoid` both contain working translations.

## Adding a language

1. Copy the template and rename it to the language code (ISO 639-1, with an
   underscore for regional variants, e.g. `pt_BR.po`):

   ```sh
   cp translate/template.pot translate/de.po
   ```

2. Fill in the `msgstr` entries. Leave the `msgid` lines untouched and keep every
   `%1`, `%2`, … placeholder. Set the header fields (`Language`, `Last-Translator`,
   `Language-Team` and, for languages with plurals, `Plural-Forms`).

3. Build the catalog:

   ```sh
   ./translate/build.sh
   ```

4. Add the language to `metadata.json` so the widget itself is translated in the
   widget chooser:

   ```json
   "Name": "Plasma Stock Monitor",
   "Name[de]": "…",
   "Description": "Modernized stock monitor for KDE with badge UI and custom colors.",
   "Description[de]": "…"
   ```

5. Restart Plasma (or at least `plasmashell`) to see the result; Ki18n evaluates
   the translations when the QML is loaded.

## Updating the sources

After changing an `i18n()` call (adding, editing or removing a string):

```sh
./translate/merge.sh
./translate/build.sh
```

`merge.sh` regenerates `template.pot` and updates each `.po`, marking changed
entries `fuzzy` and keeping obsolete ones commented out. `build.sh` then rebuilds
the `.mo` files; `msgfmt --check` fails the build if a catalog is malformed.

Both scripts need the gettext tools (`xgettext`, `msgmerge`, `msgfmt`) in `PATH`.
On NixOS:

```sh
nix shell nixpkgs#gettext
```

## Notes

- **Plurals:** use `i18np()` (singular, plural, count, …). Romanian needs three
  forms, which `ro.po` declares with
  `nplurals=3; plural=(n==1 ? 0 : (n==0 || (n%100 > 0 && n%100 < 20)) ? 1 : 2);`.
- **Contexts:** `i18nc()` is used where the same English word means different
  things, e.g. `"closed"` (market status) or the short `"Pre"` / `"After"`
  session labels.
- **Not translated on purpose:** currency names and ISO codes in
  `contents/ui/currencies.js` (they are identifiers from the exchange-rate feed),
  the CSV export header (it is a file format), ticker symbols and debug messages.
- **Data-range codes** are stored untranslated (`1D`, `5D`, …); only their labels
  are translated, so changing the language never changes the saved setting.
