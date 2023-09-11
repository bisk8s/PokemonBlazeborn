Sometimes `DebugPrintf` as shown in <https://github.com/pret/pokeemerald/wiki/Debugging-using-printf> just is not enough and we want actual source level debugging.

When developing in the C programming language we usually use `gdb`, the `GNU Debugger`. Luckily `mGBA`, a popular emulator, can run a gdb server for us.

## Prerequisites

* mGBA >= 0.10.0
* Visual Studio Code
* `arm-none-eabi-gdb` (e.g. from <https://devkitpro.org/wiki/Getting_Started>)
* MacOS

While you can probably setup `gdb` on native Windows or using any other build environment, WSL 2 is the most recommended, and this tutorial covers WSL 2.

## Check that your Build Setup is Good

Before continuing, make sure your setup will work. The easiest setup to get running to to have your code's repo live in Linux's directory rather than in Windows; so in `~/pokeemerald`, rather than `/mnt/c/User/<User>/Documents/pokeemerald`. `~` is `/home/<username>`.  
**Do not copy the Windows path to the Linux path.** `cp -r /mnt/c/User/<User>/Documents/pokeemerald ~/pokeemerald` will cause lots permissions issues. Instead, clone the GIT repo directly to `~`.

If you'd like to look at the directory in explorer, then go to it in the WSL, and type `explorer.exe .`  
After having the repo in Linux, open VSCode by running `code .` VSCode should open. In the extensions tab, install `C/C++`. I also have `WSL` and `C/C++ Extension Pack` installed.

Next, got to VSCode's terminal (`` Ctrl + ` ``), and run `make DINFO=1 modern -j$(nproc)`. If it makes the game, then you're good to continue.

## Setting up Environment Variables

We need to communicate between Windows <--> WSL 2 over a network interface. WSL changes its IP Address every time you start it (or your computer) - We can get `TODAYS_IP` by retrieving it from Windows every time we start a shell. Run the following commands depending on the shell you are using. In case you are unsure, you are probably running bash. You should see your IP address (e.g. `172.30.0.1`) and it can now be used as an environment variable.

### Bash

```sh
echo "export MGBA_EXECUTABLE=/path/to/your/windows/mGBA.exe" >> ~/.bashrc
echo "export TODAYS_IP=$(ifconfig | grep -A4 'en0:' | grep 'inet ' | awk '{print $2}' | sed -e 's/\s*//g') >> ~/.bashrc
source ~/.bashrc
echo $TODAYS_IP
```

### Zsh

```sh
echo "export MGBA_EXECUTABLE=/path/to/your/windows/mGBA.exe" >> ~/.zshrc
echo "export TODAYS_IP=$(ifconfig | grep -A4 'en0:' | grep 'inet ' | awk '{print $2}' | sed -e 's/\s*//g')" >> ~/.zshrc
source ~/.zshrc
echo $TODAYS_IP
```

Make sure to change `/path/to/your/windows/mGBA.exe` to your actual mgba path, e.g. `/mnt/c/Users/.../Documents/mGBA/mGBA.exe`.

## Setting up a Firewall rule

By default Windows blocks incoming traffic from WSL. Start up an elevated PowerShell (run `PowerShell` as Administrator in Windows) and run

```powershell
New-NetFirewallRule -DisplayName "WSL" -Direction Inbound -InterfaceAlias "vEthernet (WSL)"  -Action Allow
```

NOTE: This adds a rule to your Windows Firewall. Be aware that messing with your firewall is a potential security risk and make sure you know what you are doing.  
NOTE2: This step needs to be done every time you restart your PC. Otherwise everything compiles and mGBA opens, but nothing plays.  
NOTE3: If you're trying to set up the debugger and getting "connection timed out", the mGBA rule in the Windows firewall settings needs to be enabled for domain networks as well.

## Setting up Visual Studio Code

Open up your project in Visual Studio Code and create `.vscode/launch.json`:

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Attach to mGBA",
            "type": "cppdbg",
            "request": "launch",
            "program": "${workspaceFolder}/pokeemerald_modern.elf",
            "args":[
                "target remote ${env:TODAYS_IP}:2345"
            ],
            "stopAtEntry": true,
            "cwd": "${workspaceFolder}",
            "environment": [],
            "externalConsole": false,
            "miDebuggerServerAddress": "${env:TODAYS_IP}:2345",
            "debugServerArgs": "${workspaceFolder}/pokeemerald_modern.elf",
            "serverStarted": "started-mgba-server",
            "linux": {
                "MIMode": "gdb",
                "miDebuggerPath": "/opt/devkitpro/devkitARM/bin/arm-none-eabi-gdb",
                "debugServerPath": "${workspaceFolder}/.vscode/mgba-gdb-wrapper.sh"
            }
        }
    ]
}
```

If you are not using devkitPro `arm-none-eabi-gdb` supply your version of it under `miDebuggerPath`.

Additionally create `.vscode/tasks.json`:

```json
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "build_modern",
            "type": "shell",
            "command": "make",
            "args": [
                "DINFO=1",
                "modern",
                "-j$(nproc)"
            ],
            "group": {
                "kind": "build",
                "isDefault": true
            },
            "problemMatcher": [
                "$gcc"
            ]
        }
    ]
}
```

## Creating a launch wrapper

Create `mgba-gdb-wrapper.sh` in the `.vscode` folder of your project (so `.gitignore` will naturally ignore it):

```sh
#!/bin/bash

(
    sleep 4
    echo "started-mgba-server"
)&

"$MGBA_EXECUTABLE" $1 -g
```

Make it executable with `chmod +x .vscode/mgba-gdb-wrapper.sh`

## Using the debugger

Set any breakpoint in your Visual Studio Code editor (e.g. by clicking on a line number so it has a red dot) and press F5 to build, run, and attach gdb. The program will halt at your breakpoint and you can investigate the environment.
