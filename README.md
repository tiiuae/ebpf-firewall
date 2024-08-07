# ebpf-firewall
eBPF based firewall development

## Building from Source with Nix

* Clone the repository:

```bash 
git clone https://github.com/tiiuae/ebpf-firewall.git
cd ebpf-firewall
```
* Start nix devshell
```bash
nix develop
```

* Build the project
```bash
#release build
nix build .#ebpfFwRelease
#debug build
nix build .#ebpfFwDebug
```