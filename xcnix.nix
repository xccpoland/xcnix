{ pkgs, ... }:

pkgs.writers.writePython3Bin "xcnix" {
  libraries = [ ]; 
} ''
  import sys
  import os
  import subprocess
  import shutil

  CONFIG_PATH = "/etc/nixos/configuration.nix"
  BACKUP_PATH = "/etc/nixos/configuration.nix.bak"
  VERSION = "xtreme creations’ nix helper v0.6-unified (xc nix 0.6)"

  SPECIAL_MODULES = {
      "steam": "  programs.steam.enable = true;\n",
      "docker": "  virtualisation.docker.enable = true;\n",
      "hyprland": "  programs.hyprland.enable = true;\n"
  }

  DESKTOP_ENVIRONMENTS = {
      "gnome": {
          "signature": "services.xserver.desktopManager.gnome.enable",
          "lines": [
              "  services.xserver.enable = true;\n",
              "  services.xserver.displayManager.gdm.enable = true;\n",
              "  services.xserver.desktopManager.gnome.enable = true;\n"
          ]
      },
      "kde": {
          "signature": "services.desktopManager.plasma6.enable",
          "lines": [
              "  services.xserver.enable = true;\n",
              "  services.displayManager.sddm.enable = true;\n",
              "  services.desktopManager.plasma6.enable = true;\n"
          ]
      },
      "xfce": {
          "signature": "services.xserver.desktopManager.xfce.enable",
          "lines": [
              "  services.xserver.enable = true;\n",
              "  services.xserver.desktopManager.xfce.enable = true;\n"
          ]
      }
  }

  def verify_package(package_name):
      pkg_lower = package_name.lower()
      if pkg_lower in SPECIAL_MODULES or pkg_lower in DESKTOP_ENVIRONMENTS:
          return True 
      print(f"Checking if '{package_name}' exists in nixpkgs...")
      try:
          if shutil.which("nix-search"):
              result = subprocess.run(["nix-search", "--json", package_name], capture_output=True, text=True)
              if package_name in result.stdout:
                  return True
          result = subprocess.run(["nix-env", "-qaP", f"^{package_name}$"], capture_output=True, text=True)
          if result.stdout.strip():
              return True
      except Exception:
          pass
      print(f"❌ Error: Package '{package_name}' could not be verified.")
      return False

  def load_config():
      if not os.path.exists(CONFIG_PATH):
          print(f"Error: Could not find {CONFIG_PATH}")
          sys.exit(1)
      with open(CONFIG_PATH, 'r', encoding='utf-8') as f:
          return f.readlines()

  def save_config(lines):
      try:
          shutil.copyfile(CONFIG_PATH, BACKUP_PATH)
      except Exception as e:
          print(f"Warning: Could not create backup file: {e}")
      with open(CONFIG_PATH, 'w', encoding='utf-8') as f:
          f.writelines(lines)

  def find_system_packages_bounds(lines):
      start_idx, end_idx = -1, -1
      brace_count = 0
      in_block = False
      for idx, line in enumerate(lines):
          clean = line.strip()
          if "environment.systemPackages" in clean and "=" in clean:
              start_idx = idx
              in_block = True
          if in_block:
              brace_count += clean.count("[") - clean.count("]")
              if brace_count == 0 and "[" in lines[start_idx] or (idx != start_idx and brace_count <= 0):
                  end_idx = idx
                  break
      return start_idx, end_idx

  def list_everything():
      lines = load_config()
      content = "".join(lines)
      print("========================================")
      print(f"       System Configuration Status      ")
      print("========================================")
      active_de = "None"
      for de_name, info in DESKTOP_ENVIRONMENTS.items():
          sig = info["signature"]
          if sig in content and f"# {sig}" not in content:
              active_de = de_name.upper()
              break
      print(f"🖥️  Desktop Environment: {active_de}")
      print("\n⚡ Enabled System Modules:")
      has_modules = False
      for mod_name, config_line in SPECIAL_MODULES.items():
          if config_line.strip() in content and f"# {config_line.strip()}" not in content:
              print(f"  - {mod_name}")
              has_modules = True
      if not has_modules:
          print("  (None)")
      print("\n📦 Declared System Packages:")
      start, end = find_system_packages_bounds(lines)
      if start == -1 or end == -1:
          print("  (Could not locate systemPackages block configuration)")
          print("========================================")
          return
      has_packages = False
      declared_pkgs = []
      for idx in range(start, end + 1):
          line = lines[idx].strip()
          if "environment.systemPackages" in line or line.startswith("#") or line in ["[", "]", "];", "with pkgs;"]:
              continue
          pkg = line.replace("with pkgs;", "").replace("[", "").replace("]", "").replace(";", "").strip()
          if pkg:
              for sub_pkg in pkg.split():
                  declared_pkgs.append(sub_pkg)
                  has_packages = True
      for pkg in sorted(declared_pkgs):
          print(f"  - {pkg}")
      if not has_packages:
          print("  (No active packages explicitly declared)")
      print("========================================")

  def install_package(package_name):
      lines = load_config()
      pkg_lower = package_name.lower()
      if pkg_lower in SPECIAL_MODULES:
          target_line = SPECIAL_MODULES[pkg_lower]
          if any(target_line.strip() == l.strip() for l in lines):
              print(f"'{package_name}' module is already enabled.")
              return False
          for i in range(len(lines) - 1, -1, -1):
              if "}" in lines[i]:
                  lines.insert(i, target_line)
                  break
          save_config(lines)
          print(f"Successfully enabled the {package_name} module!")
          return True
      if not verify_package(package_name):
          sys.exit(1)
      start, end = find_system_packages_bounds(lines)
      if start == -1 or end == -1:
          print("Error: Could not locate standard environment.systemPackages block.")
          return False
      for idx in range(start, end + 1):
          if package_name in lines[idx].split():
              print(f"'{package_name}' is already declared active.")
              return False
      for idx in range(end, start - 1, -1):
          if "]" in lines[idx]:
              lines.insert(idx, f"    {package_name}\n")
              break
      save_config(lines)
      print(f"Successfully added '{package_name}' to systemPackages!")
      return True

  def uninstall_package(package_name):
      lines = load_config()
      pkg_lower = package_name.lower()
      if pkg_lower in SPECIAL_MODULES:
          target_line = SPECIAL_MODULES[pkg_lower].strip()
          modified = False
          for idx, line in enumerate(lines):
              if target_line == line.strip():
                  lines.pop(idx)
                  modified = True
                  break
          if modified:
              save_config(lines)
              print(f"Successfully removed the {package_name} module.")
              return True
          print(f"'{package_name}' module is not active.")
          return False
      start, end = find_system_packages_bounds(lines)
      if start == -1 or end == -1:
          print("Error: Could not locate systemPackages block.")
          return False
      modified = False
      for idx in range(start, end + 1):
          words = lines[idx].split()
          if package_name in words:
              words.remove(package_name)
              if not words or (len(words) == 1 and words[0] in ["[", "]"]):
                  lines[idx] = ""
              else:
                  lines[idx] = "    " + " ".join(words) + "\n"
              modified = True
              break
      if modified:
          lines = [l for l in lines if l.strip() != ""]
          save_config(lines)
          print(f"Successfully uninstalled '{package_name}' from systemPackages!")
          return True
      print(f"'{package_name}' was not found active in your configuration.")
      return False

  def set_desktop_environment(target_de):
      target_de = target_de.lower()
      if target_de not in DESKTOP_ENVIRONMENTS:
          print(f"❌ Error: Desktop Environment '{target_de}' is not supported.")
          return False
      lines = load_config()
      for de_name, info in DESKTOP_ENVIRONMENTS.items():
          sig = info["signature"]
          lines = [l for l in lines if sig not in l]
      new_block = [f"\n  # Added by xcnix\n"] + DESKTOP_ENVIRONMENTS[target_de]["lines"]
      for i in range(len(lines) - 1, -1, -1):
          if "}" in lines[i]:
              lines.insert(i, "".join(new_block))
              break
      save_config(lines)
      print(f"✨ Successfully set system desktop environment to {target_de}!")
      return True

  def prompt_rebuild():
      choice = input("Do you want to rebuild config now? [y/N]: ").strip().lower()
      if choice in ['y', 'yes']:
          print("Running: nixos-rebuild switch...")
          try:
              subprocess.run(["sudo", "nixos-rebuild", "switch"], check=True)
          except subprocess.CalledProcessError:
              print("❌ Rebuild failed. Restoring configuration backup...")
              if os.path.exists(BACKUP_PATH):
                  shutil.copyfile(BACKUP_PATH, CONFIG_PATH)
                  print("🔄 Backup configuration successfully restored.")

  if __name__ == "__main__":
      if len(sys.argv) > 1 and sys.argv[1] in ["--version", "-v"]:
          print(VERSION)
          sys.exit(0)
      if len(sys.argv) > 1 and sys.argv[1] == "list":
          list_everything()
          sys.exit(0)
      if len(sys.argv) < 3:
          print("Usage:\n  sudo xcnix install <package_name>\n  sudo xcnix uninstall <package_name>\n  sudo xcnix set-de <gnome/kde/xfce>\n  xcnix list")
          sys.exit(1)
      action, target = sys.argv[1], sys.argv[2]
      if action == "install" and install_package(target):
          prompt_rebuild()
      elif action == "uninstall" and uninstall_package(target):
          prompt_rebuild()
      elif action == "set-de" and set_desktop_environment(target):
          prompt_rebuild()
      else:
          if action not in ["install", "uninstall", "set-de"]:
              print(f"Unknown command: {action}")
              sys.exit(1)
''
