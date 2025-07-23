set allow-duplicate-recipes

project_name := `basename {{justfile_directory()}}`

default: dry-check

update dir=justfile_directory():
  nixfmt {{dir}}
  git -C {{dir}}
  nix flake update {{dir}}

updep dir: (update justfile_directory() / dir)

prepare: update

dry-check package=project_name: prepare
  nix -L --show-trace build --rebuild --dry-run "{{justfile_directory()}}#checks.x86_64-linux.{{package}}"

check package=project_name: prepare
  nix -L --show-trace build --rebuild "{{justfile_directory()}}#checks.x86_64-linux.{{package}}"

run cmd package=project_name: prepare
  nix -L --show-trace {{cmd}} "{{justfile_directory()}}#{{package}}"