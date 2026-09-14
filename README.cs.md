# MonitorShift — česky

Z libovolného Androidu udělá stolní dotykový počítač — i z telefonu
s rozbitým displejem a bez video výstupu. Raspberry Pi Zero 2 W zrcadlí
telefon po USB na dotykový monitor a dotyky posílá zpátky. Kabel dovnitř —
funguje; kabel ven — telefon se do 10 s sám vrátí do normálu. Otočíš monitor,
obraz se otočí s ním. Bez rootu, bez aplikace v telefonu.

Vzniklo kvůli Galaxy A52s s napůl mrtvým displejem, který rodina chtěla dál
používat. Anglické README má všechno podstatné; tady jen to, co je jinak
česky v kódu:

- **`stanice.sh`** — smyčka služby na Pi (čeká na telefon, připraví, zrcadlí)
- **`stanice_lib.sh`** — společné funkce: `pripravit`, `vratit`, `nasadit_hlidac`
- **`stanice_hlidac.sh`** — hlídač, který běží *v telefonu* a po 10 s bez
  kabelu vrátí původní nastavení (uložené v `settings global stanice_orig_*`)
- **`pripravit.sh` / `vratit.sh`** — ruční varianta téhož
- **`hardware/`** — STL držáku telefonu na VESA monitoru

Logy: `~/stanice.log` na Pi, `/data/local/tmp/stanice_hlidac.log` v telefonu.

Známé limity (Samsung zamykací obrazovka je černá, tablety na šířku, výkon
Zero 2 W) jsou v anglickém README v sekci *Known limits*.
