# German Training Environment - Addendum

## Spezielle Anforderungen für Deutsche Schulungsumgebungen

Diese Dokumentation ergänzt die Hauptdokumentation für spezielle deutsche Schulungsanforderungen basierend auf den bereitgestellten Spezifikationen.

## Schulungsarchitektur

### **Kalkulation: 5 Schüler + 1 Trainer**

Jeder Teilnehmer (Schüler oder Trainer) erhält folgende VM-Ausstattung:

| VM-Typ       | Anzahl | OS                  | CPU | RAM  | HDD   |
| ------------ | ------ | ------------------- | --- | ---- | ----- |
| Server DC    | 1      | Windows Server 2022 | 2   | 4 GB | 50 GB |
| Server TS    | 1      | Windows Server 2019 | 2   | 4 GB | 50 GB |
| Server01     | 1      | Windows Server 2022 | 2   | 4 GB | 50 GB |
| Client01     | 1      | Windows 10          | 2   | 4 GB | 50 GB |
| Client02     | 1      | Windows 11          | 2   | 4 GB | 50 GB |
| **Jumphost** | 1      | Windows 10/11       | 2   | 4 GB | 50 GB |

**Gesamt pro Teilnehmer**: 6 VMs (5 Arbeits-VMs + 1 Jumphost)  
**Gesamt für Schulung**: 36 VMs (6 Teilnehmer × 6 VMs)

## Jumphost-Architektur (Empfohlen)

### **Vorteile des Jumphost-Ansatzes:**

- **Vereinfachter Zugang**: Schüler verbinden sich nur zum Jumphost
- **Bessere Übersicht**: Alle Systeme von einem Desktop aus erreichbar
- **Netzwerksicherheit**: Nur Jumphost benötigt öffentliche IP
- **Kosteneinsparung**: Weniger öffentliche IP-Adressen erforderlich

### **Netzwerk-Konfiguration:**

#### Mit Jumphost:

```
Internet → Jumphost (2 NICs) → Internal Network → VMs (1 NIC each)
```

- **Jumphost**: 2 Netzwerkkarten (Public + Private)
- **Arbeits-VMs**: 1 Netzwerkkarte (Private only)

#### Ohne Jumphost (Alternative):

```
Internet → Public IPs → VMs (2 NICs each)
```

- **Alle VMs**: 2 Netzwerkkarten (Public + Private)

## Verwendung des Scripts

### **Deutsche Schulungsumgebung erstellen:**

```powershell
.\az-ps-create-devtest-training-environment.ps1 `
    -LabName "WindowsServerSchulung2025" `
    -ResourceGroupName "schulung-rg" `
    -Location "Germany West Central" `
    -StudentCount 5 `
    -IncludeTrainer $true `
    -UseJumphost $true `
    -JumphostSize "Standard_B2ms" `
    -VMSize "Standard_B2s" `
    -TrainingUserEmails @(
        "schueler1@firma.de",
        "schueler2@firma.de",
        "schueler3@firma.de",
        "schueler4@firma.de",
        "schueler5@firma.de"
    ) `
    -InstructorEmails @("trainer@firma.de") `
    -AutoShutdownTime "1800" `
    -AutoStartupTime "0800" `
    -TimeZoneId "W. Europe Standard Time" `
    -TrainingDuration 5 `
    -Action Create
```

### **Umgebung ohne Jumphost (alle VMs öffentlich):**

```powershell
.\az-ps-create-devtest-training-environment.ps1 `
    -LabName "WindowsServerSchulung2025" `
    -ResourceGroupName "schulung-rg" `
    -Location "Germany West Central" `
    -StudentCount 5 `
    -IncludeTrainer $true `
    -UseJumphost $false `
    -AllowPublicIP $true `
    -Action Create
```

## Zugangsverfahren für Schüler

### **Mit Jumphost (Empfohlen):**

1. **RDP-Verbindung** zum zugewiesenen Jumphost

   - Jumphost-IP: wird vom Lab bereitgestellt
   - Benutzername: `trainer`
   - Passwort: `Training123!`

2. **Vom Jumphost aus** zu den Arbeits-VMs verbinden:

   - Server DC: RDP zu `ServerDC-S01` (interne IP)
   - Server TS: RDP zu `ServerTS-S01` (interne IP)
   - Weitere VMs entsprechend

3. **VM-Anmeldedaten** für Arbeits-VMs:
   - Benutzername: `administrator`
   - Passwort: `Training123!`

### **Ohne Jumphost:**

1. **Direkte RDP-Verbindungen** zu jeder VM
2. **Jede VM** hat eigene öffentliche IP-Adresse
3. **Anmeldung** direkt an jeder VM mit entsprechenden Credentials

## Kostenoptimierung

### **Automatische Richtlinien:**

- **Auto-Shutdown**: 18:00 Uhr (nach Schulungsende)
- **Auto-Startup**: 09:00 Uhr (vor Schulungsbeginn)
- **Schulungszeit**: 9 Stunden täglich (09:00 - 18:00 Uhr)
- **Zeitzone**: "W. Europe Standard Time"
- **Schulungsdauer**: Konfigurierbar (Standard: 5 Tage)

### **Detaillierte Kostenschätzung (9 Stunden täglich):**

#### **VM-Größen und Stundenpreise (Germany West Central):**

| VM-Typ          | Größe    | vCPUs | RAM  | Preis/Stunde | Preis/9h Tag |
| --------------- | -------- | ----- | ---- | ------------ | ------------ |
| Standard_B2s    | B-Series | 2     | 4 GB | €0,042       | €0,38        |
| Standard_B2ms   | B-Series | 2     | 8 GB | €0,083       | €0,75        |
| Standard_D2s_v3 | D-Series | 2     | 8 GB | €0,096       | €0,86        |

#### **Kostenaufschlüsselung pro Teilnehmer (9 Stunden/Tag):**

**Standard_B2s VMs (empfohlen für Training):**

- **5 Arbeits-VMs**: 5 × €0,38 = €1,90/Tag
- **1 Jumphost**: 1 × €0,38 = €0,38/Tag
- **Gesamt pro Teilnehmer**: €2,28/Tag

#### **Gesamtkosten für 5 Schüler + 1 Trainer:**

| Komponente  | Anzahl       | Kosten/Tag | Kosten/Woche (5 Tage) |
| ----------- | ------------ | ---------- | --------------------- |
| Schüler-VMs | 30 VMs (5×6) | €11,40     | €57,00                |
| Trainer-VMs | 6 VMs (1×6)  | €2,28      | €11,40                |
| **Gesamt**  | **36 VMs**   | **€13,68** | **€68,40**            |

#### **Zusätzliche Azure-Kosten:**

| Service               | Kosten/Tag | Beschreibung                       |
| --------------------- | ---------- | ---------------------------------- |
| Storage (OS Disks)    | €3,60      | 36 × 50GB Standard SSD (€0,10/Tag) |
| Network (Public IPs)  | €2,16      | 6 Public IPs × €0,36/Tag           |
| DevTest Labs Service  | €0,00      | Kostenlos                          |
| **Storage & Network** | **€5,76**  | **Zusätzlich zu VM-Kosten**        |

#### **Vollständige Kostenübersicht:**

| Zeitraum                | VM-Kosten | Storage & Network | **Gesamtkosten** |
| ----------------------- | --------- | ----------------- | ---------------- |
| **Pro Tag (9h)**        | €13,68    | €5,76             | **€19,44**       |
| **Pro Woche (5 Tage)**  | €68,40    | €28,80            | **€97,20**       |
| **Pro Monat (20 Tage)** | €273,60   | €115,20           | **€388,80**      |

### **Kostenvergleich: 9h vs 24h Betrieb:**

| Betriebszeit                  | Tägliche VM-Kosten | Wöchentliche Gesamtkosten |
| ----------------------------- | ------------------ | ------------------------- |
| **9 Stunden** (Training)      | €13,68             | €97,20                    |
| **24 Stunden** (Dauerbetrieb) | €36,48             | €211,20                   |
| **Einsparung**                | €22,80 (62%)       | €114,00 (54%)             |

### **Kostenoptimierungsstrategien:**

#### **Automatische Zeitsteuerung:**

```powershell
# 9-Stunden Schulungstag (09:00 - 18:00)
-AutoStartupTime "0900" `
-AutoShutdownTime "1800" `
-TimeZoneId "W. Europe Standard Time"
```

#### **Weitere Einsparungen:**

- **Wochenenden**: Automatisches Herunterfahren (keine Kosten)
- **VM-Größe**: B2s für Training ausreichend (günstigste Option)
- **Regionen**: Germany West Central oft günstiger als andere EU-Regionen
- **Reserved Instances**: Bis zu 40% Rabatt bei längerfristiger Nutzung

#### **Kostenkontrolle:**

```powershell
# Budget-Alerts einrichten
-CostThreshold 100 `  # Alert bei €100/Woche
-TrainingDuration 5   # Automatische Löschung nach 5 Tagen
```

### **Kostenreduzierung:**

- **VMs laufen nur 9 Stunden/Tag**: 62% Einsparung gegenüber 24/7-Betrieb
- **Automatisches Herunterfahren**: Keine Kosten außerhalb der Schulungszeiten
- **Jumphost-Architektur**: Weniger öffentliche IPs benötigt
- **Sofortige Löschung**: Nach Schulungsende keine weiteren Kosten

## Erweiterte Konfiguration

### **Integration mit bestehenden Systemen:**

#### **Config.XO Integration:**

```powershell
# Zusätzliche Parameter für Config.XO
-ConfigXOIntegration $true `
-ConfigXOServer "config.xo.server.de" `
-AutoConfigDeployment $true
```

#### **Installationsskripte:**

- **Speicherort**: Azure DevTest Labs Artifact Repository
- **Dokumentation**: Im Lab unter "Artifacts" → "Public Repository"
- **Custom Scripts**: Können über private Git-Repository hinzugefügt werden

### **Separate Subscription:**

```powershell
# Spezielle Subscription für Labs
-SubscriptionId "12345678-1234-1234-1234-123456789012" `
-ResourceGroupName "training-labs-subscription"
```

## Netzwerk- und Sicherheitskonfiguration

### **Jumphost-Sicherheit:**

- **Nur RDP-Port (3389)** öffentlich erreichbar
- **Windows Firewall** aktiviert
- **Netzwerksegmentierung** zwischen Jumphost und Arbeits-VMs
- **Automatische Updates** aktiviert

### **Arbeits-VMs Sicherheit:**

- **Keine öffentlichen IPs** (bei Jumphost-Architektur)
- **Interne Netzwerk-Kommunikation** nur
- **Standardsicherheitsgruppen** angewendet
- **Domain Controller** für zentrale Authentifizierung

## Betrieb und Wartung

### **Überwachung:**

```powershell
# Status aller VMs prüfen
.\az-ps-devtest-lab-ops.ps1 `
    -LabName "WindowsServerSchulung2025" `
    -ResourceGroupName "schulung-rg" `
    -Operation Status

# Alle VMs starten
.\az-ps-devtest-lab-ops.ps1 `
    -LabName "WindowsServerSchulung2025" `
    -ResourceGroupName "schulung-rg" `
    -Operation StartAll
```

### **Notfall-Procedures:**

```powershell
# Alle VMs sofort stoppen (Kostenkontrolle)
.\az-ps-devtest-lab-ops.ps1 `
    -LabName "WindowsServerSchulung2025" `
    -ResourceGroupName "schulung-rg" `
    -Operation StopAll

# Komplette Umgebung löschen
.\az-ps-create-devtest-training-environment.ps1 `
    -LabName "WindowsServerSchulung2025" `
    -ResourceGroupName "schulung-rg" `
    -Action Delete
```

## Häufige Fragen (FAQ)

### **F: Wo liegen die Installationsskripte?**

**A:** Die Installationsskripte werden als Azure DevTest Labs Artifacts bereitgestellt:

- Public Repository: Über Azure DevTest Labs verfügbar
- Custom Repository: Kann über Git-Integration hinzugefügt werden
- Lokal: Im `artifacts/` Ordner des Labs

### **F: Wo ist die Dokumentation zu den Installationsskripten?**

**A:**

- Azure Portal → DevTest Labs → "Artifacts"
- GitHub: Public DevTest Labs Repository
- Lab-interne Dokumentation unter "Policies and settings"

### **F: Jumphost oder externes Gateway?**

**A:** **Jumphost ist empfohlen** weil:

- Einfacherer Zugang für Schüler
- Bessere Übersicht über alle Systeme
- Geringere Netzwerk-Komplexität
- Kostengünstiger (weniger öffentliche IPs)

### **F: Wie wird die Separate Subscription eingerichtet?**

**A:**

1. Neue Azure Subscription erstellen
2. `-SubscriptionId` Parameter im Script verwenden
3. Entsprechende Berechtigungen für Benutzer zuweisen
4. Separate Budgets und Alerts konfigurieren

## Troubleshooting

### **Häufige Probleme:**

#### **Jumphost nicht erreichbar:**

```powershell
# Jumphost-Status prüfen
Get-AzVM -ResourceGroupName "schulung-rg" -Name "Jumphost-S01" -Status

# NSG-Regeln prüfen
Get-AzNetworkSecurityGroup -ResourceGroupName "schulung-rg"
```

#### **VMs starten nicht automatisch:**

```powershell
# Auto-Start Policy prüfen
Get-AzDtlAutoStartPolicy -LabName "WindowsServerSchulung2025" -ResourceGroupName "schulung-rg"

# Policy aktualisieren
Set-AzDtlAutoStartPolicy -LabName "WindowsServerSchulung2025" -ResourceGroupName "schulung-rg" -Time "0800" -TimeZoneId "W. Europe Standard Time" -Enable
```

#### **Zu hohe Kosten:**

```powershell
# Sofortiges Herunterfahren
.\az-ps-devtest-lab-ops.ps1 -Operation StopAll

# Kostenanalyse
.\az-ps-devtest-lab-ops.ps1 -Operation CostReport -Days 7
```

---

**Hinweis**: Diese Konfiguration ist optimiert für deutsche Schulungsumgebungen und berücksichtigt die spezifischen Anforderungen von 5 Schülern + 1 Trainer mit Jumphost-Architektur.
