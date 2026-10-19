# installed.sh <gen> [explicit|all]
# Lista los paquetes instalados con pacman para el panel de "Instalados" de PackageSearch (solo Arch). Los paquetes de AUR son los "foráneos" de pacman (`pacman -Qm`: los que no están en ningún repo sincronizado), así q…

gen="${1:-0}"
scope="${2:-explicit}"

echo "$gen"
command -v pacman >/dev/null 2>&1 || { echo "__NO_PACMAN__"; exit 127; }

flag=()
[ "$scope" = "explicit" ] && flag=(-e)

export LC_ALL=C
foreign=" $(pacman -Qmq 2>/dev/null | tr '\n' ' ')"

pacman -Qi "${flag[@]}" 2>/dev/null | awk -v F="$foreign" '
function flush() {
  if (name != "") {
    gsub(/\t/, " ", desc)
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", name, ver, size, reason, desc, \
           (index(F, " " name " ") > 0 ? "1" : "0"), repo
  }
  name = ""; ver = ""; size = ""; reason = "d"; desc = ""; repo = ""
}
BEGIN { reason = "d" }
{
  k = $0; sub(/ *:.*/, "", k)
  v = $0; sub(/^[^:]*: */, "", v)
}
k == "Name"           { flush(); name = v }
k == "Version"        { ver = v }
k == "Description"    { desc = v }
k == "Installed Size" { size = v }
k == "Repository"     { repo = v }
k == "Install Reason" { reason = (tolower(v) ~ /explicitly/) ? "e" : "d" }
END { flush() }
'
