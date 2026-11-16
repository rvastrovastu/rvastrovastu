# Adds the Today highlight strings (all languages) and the vastu summary
# strings (English) to your ARB files. Existing keys are never overwritten.
# Usage, from the project root:  python3 tools/restore_strings.py .
import glob, json, os, shutil, sys

root = sys.argv[1] if len(sys.argv) > 1 else "."
here = os.path.dirname(os.path.abspath(__file__))
flash = json.load(open(os.path.join(here, "flash_strings.json"), encoding="utf-8"))
vastu = json.load(open(os.path.join(here, "vastu_summaries_en.json"), encoding="utf-8"))

for path in sorted(glob.glob(os.path.join(root, "lib", "l10n", "app_*.arb"))):
    lang = os.path.basename(path)[4:-4]
    new = dict(flash.get(lang, {}))
    if lang == "en":
        new.update(vastu)
    with open(path, encoding="utf-8") as f:
        target = json.load(f)
    added = [k for k in new if k not in target and not k.startswith("@@")]
    for k, v in new.items():
        target.setdefault(k, v)
    if added:
        shutil.copy(path, path + ".bak")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(target, f, ensure_ascii=False, indent=2)
            f.write("\n")
    print(f"{lang}: {len(added)} keys added")
print("Done. Now run: flutter pub get && flutter analyze")
