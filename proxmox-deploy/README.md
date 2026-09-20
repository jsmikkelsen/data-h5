# Proxmox Udrulning med Ansible & Cloud-Init

Dette projekt giver en nem, hurtig og automatiseret måde at udrulle både **Virtuelle Maskiner (VMs)** og **LXC Containere** i Proxmox VE ved brug af **Ansible** og **Cloud-Init**.

Med denne løsning kan du udrulle og konfigurere nye VM'er på under et minut med korrekte netværksindstillinger, SSH-nøgler og brugere, helt uden at skulle klikke rundt i Proxmox Web UI.

---

## Projektstruktur

```text
data-h5/proxmox-deploy/
├── README.md                     # Denne vejledning og dokumentation
├── create_cloudinit_template.sh  # Script til Proxmox Host CLI for at oprette Cloud-Init skabelon
├── ansible.cfg                   # Ansible konfigurationsfil (optimeringer)
├── hosts.yml                     # Ansible Inventory (forbindelsesdetaljer)
├── vars.yml                      # Central variable-fil til dine VM'er og LXC'er
├── deploy_vm.yml                 # Playbook til udrulning af VM'er ud fra skabelon
└── deploy_lxc.yml                # Playbook til udrulning af LXC containere
```

---

## Forudsætninger

For at bruge denne løsning skal du have:
1. **Ansible** installeret på din egen maskine:
   ```bash
   pip install ansible
   # eller via Homebrew på macOS
   brew install ansible
   ```
2. Installer den nødvendige Proxmox integration til Ansible:
   ```bash
   ansible-galaxy collection install community.general
   ```
3. Installer Python-biblioteket `proxmoxer` på din lokale maskine (kræves af Ansible Proxmox-modulerne):
   ```bash
   pip install proxmoxer requests
   ```
4. **En Cloud-Init VM-skabelon (Template)** på din Proxmox. Hvis du ikke har en endnu, kan du nemt oprette en ved hjælp af det medfølgende script (se næste afsnit).

---

## Trin 1: Opret en Cloud-Init Skabelon i Proxmox (KUN ÉN GANG)

For at Ansible kan udrulle VM'er lynhurtigt, skal der ligge en "base-skabelon" i Proxmox. 
Vi har lavet scriptet `create_cloudinit_template.sh`. 

1. Kopier indholdet af `create_cloudinit_template.sh` og kør det direkte på din **Proxmox Vært (Host) via SSH eller Proxmox Shell**:
   ```bash
   # Log ind på din Proxmox host
   ssh root@<din-proxmox-ip>
   
   # Hent og kør scriptet, eller opret det manuelt derinde
   nano create_cloudinit_template.sh
   # Indsæt indholdet af create_cloudinit_template.sh
   chmod +x create_cloudinit_template.sh
   ./create_cloudinit_template.sh
   ```
   *Dette script henter Ubuntu 24.04 LTS Cloud-Image, installerer QEMU Guest Agent (så Proxmox kan se IP m.m.), opsætter Cloud-Init og omdanner maskinen til en skabelon med VMID **9000**.*

---

## Trin 2: Konfigurer dine variabler i `vars.yml`

Åbn `vars.yml` og tilpas indstillingerne, så de matcher dit netværk og din Proxmox-opsætning:
- Indtast din Proxmox IP/domæne (`proxmox_api_host`).
- Indtast dine API-oplysninger eller din root-adgang (det anbefales at bruge API Token for sikkerhed).
- Tilføj din offentlige SSH-nøgle under `cloudinit_ssh_keys`, så du kan logge ind på dine nye VM'er uden adgangskode.
- Definer de VM'er og LXC containere, du ønsker at oprette.

---

## Trin 3: Udrulning (Deploy)

Når variablerne er sat op, kan du køre playbooks fra din egen computer:

### A) Udrul Virtuelle Maskiner (VM'er)
For at oprette de definerede VM'er (klonet fra din Cloud-Init skabelon):
```bash
ansible-playbook -i hosts.yml deploy_vm.yml
```

### B) Udrul LXC Containere
For at oprette LXC containere (f.eks. til letvægts applikationer/Docker hosts):
```bash
ansible-playbook -i hosts.yml deploy_lxc.yml
```

---

## Protip: API Token i Proxmox (Anbefalet)
I stedet for at skrive din root-adgangskode i `vars.yml`, kan du oprette et API Token i Proxmox Web UI under **Datacenter -> API Tokens**.

Giv tokenet følgende rettigheder (eller Administrator rolle) og indsæt værdierne i `vars.yml`:
- `proxmox_api_token_id: "root@pam!ansible-token"`
- `proxmox_api_token_secret: "din-lang-token-secret-her"`

## Cloud-Init i funktion
Når Ansible udruller en VM:
1. Den kloner skabelonen (VMID 9000) til en ny VM med det valgte VMID og navn.
2. Den overskriver CPU, RAM og diskstørrelse i Proxmox efter dine ønsker.
3. Den indsprøjter din SSH-nøgle, standardbruger (`ubuntu` eller hvad du vælger), adgangskode samt netværksopsætning (statisk IP eller DHCP).
4. Maskinen starter, Cloud-Init konfigurerer systemet automatisk ved første opstart, og maskinen er klar til brug på under et minut!
