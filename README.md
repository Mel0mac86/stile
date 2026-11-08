# MyWardrobe AI – Il tuo stilista personale

App nativa iPhone (Swift, SwiftUI, SwiftData) per fotografare i tuoi capi, costruire il guardaroba digitale
e ricevere abbinamenti che usano **solo** i vestiti che possiedi. Tutto gira in locale: nessun account,
nessun abbonamento. Le uniche chiamate di rete sono quelle del meteo (Open-Meteo, gratuito) e quelle
per cercare la località della valigia, e avvengono solo se le usi.

---

## Stato delle fasi

| Fase | Contenuto | Stato |
|---|---|---|
| 1 | Architettura: modelli, servizi, viste, separazione logica/UI | Fatta (vedi "Architettura") |
| 2 | Interfaccia SwiftUI: 5 sezioni, chiaro/scuro, navigazione | Fatta |
| 3 | Fotocamera e galleria (`UIImagePickerController`, `PhotosPicker`) | Fatta |
| 4 | Guardaroba: schede modificabili, categorie, filtro, eliminazione | Fatta |
| 5 | Riconoscimento: rimozione sfondo, tipo, colori, fantasia | Fatta, con limiti (vedi sotto) |
| 6 | Motore di abbinamento: colori, stile, stagione, meteo, occasione | Fatta |
| 7 | Occasioni (17 + descrizione libera), meteo, stagioni, valigia | Fatta |
| 8 | Preferiti, cronologia, calendario, valutazioni, apprendimento, capi dimenticati | Fatta |
| 9 | Test: unit test del motore e dei colori; verifica della logica su macOS | Parziale (vedi "Verifiche") |
| 10 | Backup/ripristino, cancellazione dati, guida di installazione, icona, file di privacy | Fatta; resta solo la pubblicazione su App Store |

"Fatta" indica che il codice è scritto. La compilazione per iPhone non è ancora stata eseguita in Xcode:
vedi "Verifiche".

---

## Funzioni

- **Guardaroba**: foto con fotocamera o galleria; ritaglio automatico del capo e rimozione dello sfondo
  (Vision, iOS 17+); scheda modificabile con nome, categoria, sottocategoria, colore principale e secondario,
  fantasia, stagioni, materiale, marca, taglia, stile, note.
- **Stilista AI**: per ogni richiesta propone fino a 3 outfit diversi (oppure un outfit casuale). Segnala
  chiaramente i capi mancanti (es. "Manca un paio di scarpe", "Manca una giacca per il freddo").
- **Dettaglio outfit**: composizione grafica dei capi, motivi per cui stanno bene insieme, valutazione a
  stelle, "Sostituisci" per cambiare un solo capo mantenendo gli altri, "Indossato oggi", preferiti.
- **Occasioni**: le 17 della specifica + una descrizione libera ("festa in terrazza" → Festa).
- **Meteo**: con il tuo consenso legge temperatura, pioggia, vento e umidità; altrimenti imposti la
  temperatura a mano. La stagione si sceglie sempre a mano.
- **Preferiti / Cronologia / Calendario**: outfit salvati, storia completa, e giorno per giorno ciò che
  hai indossato.
- **Apprendimento**: le valutazioni spostano i punteggi dei capi; lo stile preferito del profilo pesa
  sui suggerimenti.
- **Capi dimenticati**: avviso per i capi non indossati da 60 giorni (o mai indossati dopo 60 giorni).
- **Valigia automatica**: durata, data di partenza e destinazione (previsioni fino a 16 giorni). Produce
  una checklist e segnala ciò che manca.
- **Backup**: esporta/importa un file JSON con capi, foto, outfit e calendario. Cancella tutti i dati con
  una conferma.

---

## Struttura del progetto

```
stile/
├── project.yml                     Configurazione XcodeGen (genera il file .xcodeproj)
├── README.md
├── MyWardrobeAI/
│   ├── App/
│   │   ├── MyWardrobeAIApp.swift   Punto d'ingresso, contenitore SwiftData, tema
│   │   └── RootTabView.swift       Menu inferiore con le 5 sezioni
│   ├── Models/                     Dati e tipi puri (nessuna UI)
│   │   ├── GarmentCategory.swift   Categorie, slot, calore, eleganza; Season; GarmentStyle
│   │   ├── Occasion.swift          Occasioni e riconoscimento da testo libero
│   │   ├── Garment.swift           @Model del capo (SwiftData)
│   │   ├── GarmentDraft.swift      Bozza modificabile di una scheda
│   │   ├── SavedOutfit.swift       @Model outfit salvato e @Model giorno indossato
│   │   ├── OutfitSession.swift     Outfit aperto nel dettaglio (valore per la navigazione)
│   │   └── AppSettings.swift       Chiavi delle preferenze e tema
│   ├── Services/                   Logica senza UI
│   │   ├── ImageStore.swift        Foto come file privati nell'app (mai caricate)
│   │   ├── GarmentStore.swift      Salvataggio/eliminazione capi (file + database)
│   │   ├── GarmentAnalyzer.swift   Pipeline: sfondo → classificazione → colori (Vision)
│   │   ├── ColorAnalysis.swift     Colori dominanti, palette, armonia tra colori
│   │   ├── OutfitEngine.swift      Motore di abbinamento, alternative, apprendimento
│   │   ├── PackingPlanner.swift    Valigia
│   │   ├── WeatherService.swift    Posizione (con consenso) e meteo Open-Meteo
│   │   ├── BackupService.swift     Backup JSON, ripristino, cancellazione
│   │   └── BackupDocument.swift    Documento per il selettore di file
│   └── Views/
│       ├── HomeView.swift          Home: meteo, capi dimenticati, outfit del giorno
│       ├── WardrobeView.swift      Guardaroba, griglia, modifica e elimina capo
│       ├── AddGarmentView.swift    Flusso di aggiunta: foto → analisi → scheda
│       ├── GarmentFormView.swift   Scheda modificabile condivisa
│       ├── StylistView.swift       Stilista AI: occasione, stagione, meteo, proposte
│       ├── OutfitDetailView.swift  Dettaglio, sostituzione, valutazione, calendario
│       ├── FavoritesView.swift     Preferiti, cronologia, calendario
│       ├── ProfileView.swift       Preferenze, strumenti, backup, privacy
│       ├── PackingView.swift       Valigia
│       └── Common/                 Componenti riusabili (immagini, fotocamera, card outfit)
├── MyWardrobeAITests/
│   └── OutfitEngineTests.swift     Unit test di motore, colori, occasioni, valigia
└── scripts/
    ├── verify_logic.sh             Verifica la logica fuori da Xcode (vedi "Verifiche")
    └── LogicSelfTest.swift         I controlli eseguiti dallo script
```

---

## Aprire e compilare con Xcode

Requisiti: un Mac con **Xcode 16 o successivo** (iOS 17 SDK) e un account Apple (anche gratuito per
installare sul proprio iPhone).

1. Installa XcodeGen (una volta sola):
   ```bash
   brew install xcodegen
   ```
2. Dalla cartella del progetto genera il file Xcode:
   ```bash
   xcodegen generate
   ```
3. Apri `MyWardrobeAI.xcodeproj`.
4. In **Signing & Capabilities**, seleziona il tuo **Team**. In alternativa inserisci il tuo Team ID in
   `project.yml` alla voce `DEVELOPMENT_TEAM` e rigenera il progetto.
5. Scegli uno schema iPhone (simulatore o dispositivo) e premi **⌘R**.

Note:
- La fotocamera non funziona nel simulatore: usa la galleria, oppure un iPhone vero.
- Il riconoscimento usa Vision: sul simulatore può essere più lento o meno preciso.
- Esegui i test con **⌘U**.

## Installare l'app su iPhone

1. Collega l'iPhone al Mac con il cavo e sbloccalo. Accetta "Fidati di questo computer".
2. Su iPhone attiva **Modalità sviluppatore** (Impostazioni → Privacy e sicurezza → Modalità sviluppatore,
   iOS 16 o successivo) e riavvia.
3. In Xcode scegli il tuo iPhone come destinazione e premi **⌘R**.
4. La prima volta, su iPhone vai in Impostazioni → Generali → VPN e gestione dispositivo, tocca il tuo
   profilo sviluppatore e scegli **Considera attendibile**.
5. Con un account gratuito l'app scade dopo 7 giorni: basta ripetere ⌘R. Con l'account a pagamento
   Apple Developer dura un anno e puoi distribuirla con TestFlight.

---

## Come aggiungere nuove funzionalità

- **Nuovo campo nel capo**: aggiungilo a `Garment` (con valore di default), a `GarmentDraft` e alle
  funzioni `init(garment:)` e `update(from:)`. Poi mostralo in `GarmentFormView`. Per il backup aggiungi
  il campo a `BackupService.GarmentRecord`: con un valore di default il vecchio backup si legge ancora.
- **Nuova categoria**: aggiungi il caso a `GarmentCategory` e completa `slot`, `warmth`, `defaultFormality`
  e `symbolName` (il compilatore segnala i `switch` incompleti). Aggiungi le parole chiave in
  `GarmentAnalyzer.category(for:)` se Vision la riconosce.
- **Nuova occasione**: aggiungi il caso a `Occasion` con `formality`, `symbolName` e una regola in
  `Occasion.inferred(from:)`.
- **Regole di abbinamento**: sono in `OutfitEngine.evaluate`. Ogni criterio è un punteggio 0...1 con un
  peso; ogni motivo o avviso è una riga di testo. Aggiungi un test in `OutfitEngineTests`.
- **Colori**: `ColorAnalysis.palette` e `harmony(_:_:)`.
- **Meteo**: `WeatherService` è l'unico punto che parla con la rete per il meteo.
- **Schermata nuova**: crea la vista in `Views/` e collegala in `RootTabView` o con `NavigationLink`.
  Per aprire un outfit, passa un `OutfitSession` e usa `navigationDestination` già presente.

Convenzioni: la logica sta in `Models`/`Services` e non importa SwiftUI (tranne `AppSettings` e
`BackupDocument`); le viste solo presentano. Ogni funzione pubblica ha un commento in italiano.

---

## Privacy

- Le foto sono file nella cartella privata dell'app (`Application Support/Capi`). Non vengono caricate.
- Nessun account. Le preferenze sono in `UserDefaults`.
- La posizione è richiesta solo con il consenso per il meteo, e non viene salvata.
- Il backup è un file che scegli tu di salvare (es. iCloud Drive). Contiene anche le foto.
- "Cancella tutti i dati" elimina database e foto.

---

## Decisioni di architettura (e conseguenze)

1. **SwiftData, iOS 17 minimo.** Meno codice di Core Data e modelli con macro. Conseguenza: non si
   installa su iOS 16 o precedenti.
2. **Motore di abbinamento a regole, non un modello di linguaggio.** È deterministico, gira offline e non
   costa nulla. Conseguenza: i suggerimenti sono buoni ma non creativi; si migliorano con nuove regole.
3. **Vision per il ritaglio (`VNGenerateForegroundInstanceMaskRequest`, iOS 17).** Nessun modello da
   scaricare. Conseguenza: funziona bene su capi fotografati su sfondo contrastante; su sfondi simili al
   capo il ritaglio può essere imperfetto. In quel caso si usa la foto intera.
4. **Classificazione con `VNClassifyImageRequest` e parole chiave.** Vision non ha una tassonomia di capi
   d'abbigliamento dedicata. Conseguenza: il tipo proposto è un suggerimento. Quando non è riconosciuto
   compare "Altro", e l'utente lo corregge. Un modello Core ML dedicato si inserisce in `GarmentAnalyzer`
   senza toccare il resto.
5. **Open-Meteo al posto di WeatherKit.** WeatherKit richiede un account sviluppatore e un servizio a
   pagamento oltre una soglia; Open-Meteo è gratuito e senza chiave. Conseguenza: serve connessione e il
   servizio è esterno; i dati arrivano senza richiedere nulla all'utente.
6. **`UIImagePickerController` per la fotocamera, invece di AVFoundation a mano.** Scatto affidabile e
   poco codice. Conseguenza: non si personalizza l'interfaccia della fotocamera. Per un controllo più fine
   si sostituisce `CameraPicker` con una sessione AVFoundation.
7. **XcodeGen (`project.yml`) invece di un `.xcodeproj` committato.** Il progetto resta leggibile e senza
   conflitti di merge. Conseguenza: serve installare XcodeGen una volta.

---

## Limiti noti (da sapere prima dell'uso)

- **Materiale e stile non sono riconosciuti dalla foto**: li imposti tu nella scheda. Lo stile viene
  suggerito dalla categoria.
- **Fantasia**: riconosciuta con un'euristica sui colori (molti colori distinti, nessuno dominante). Può
  sbagliare su foto con ombre forti.
- **Classificazione**: dipende dalle etichette generiche di Vision (vedi decisione 4).
- **Calore e stagione** sono proprietà della categoria e della scheda, non misurate.
- **La valigia** non conosce le attività del viaggio (es. trekking): usa occasione "Viaggio".
- **Icona dell'app**: è un segnaposto generato da `scripts/make_app_icon.swift` (appendino su fondo beige). Sostituisci
  `AppIcon-1024.png` con il design definitivo, stesso nome e dimensione.

---

## Verifiche

Ciò che è stato verificato e ciò che no. Non dichiarare l'app "compilata per iPhone" senza aver eseguito
⌘B in Xcode.

- **Non verificato**: la compilazione per iOS, l'esecuzione sul simulatore e i test XCTest, perché
  l'ambiente di sviluppo usato per scrivere il codice non ha Xcode né l'SDK iOS. La prima cosa da fare
  è `xcodegen generate` e ⌘B, poi ⌘U.
- **Verificato**:
  - Sintassi di tutti i 33 file Swift (`swiftc -parse`).
  - Logica (modelli, motore outfit, colori, occasioni, valigia, backup JSON, etichette Vision) compilata
    con il toolchain macOS e testata con `scripts/verify_logic.sh`: 25 controlli, tutti superati.
    Per questo controllo SwiftData è sostituito da uno stub, perché le macro `@Model` richiedono Xcode.
  - Le viste SwiftUI non sono state type-checkate: usano UIKit, non disponibile su macOS.

## Pubblicazione futura su App Store (fase 10)

Già presenti: icona 1024×1024 senza trasparenza (`Assets.xcassets/AppIcon.appiconset`) e il manifest
`MyWardrobeAI/PrivacyInfo.xcprivacy`. Il manifest dichiara: nessun tracciamento; posizione approssimativa
inviata a Open-Meteo solo se attivi il meteo (non collegata all'identità); uso di UserDefaults per le
preferenze locali.

Da fare prima dell'invio:
- Controllare il manifest con i dati reali dell'app: se aggiungi un servizio esterno, aggiornalo.
- Scrivere la pagina di privacy pubblica (le foto restano sul dispositivo, la posizione è facoltativa).
- Verificare le schermate per iPad se vuoi supportarlo (oggi l'app è solo iPhone, in verticale).
