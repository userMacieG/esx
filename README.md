# ESX

ESX v1, Hawaii Edition. Just got screwed on the internet for the last time, so here's my continued efforts to improve ESX. After snake gizz kicked me off he merged PRs with no standard, and done other things making it worse, then abandoned it for his v2 and I'll let y'all keep speculating why he isn't ever online anymore 🔪 🐍

The point of this repo is not to replace the mainstream ESX installation, ever. It's intended to teach people of improvements that could be made to the framework. I'll keep making breaking changes to improve the framework. Improvements made are mainly optimizations so you can run >100 players with it, which you definitely cannot run with the original code.

It also doesn't come with a inventory since you shouldn't be using that garbage UI for that, make a real one.

For OGs I made a development discord: https://discord.gg/H86eaEPwvK

## Installation

### Configuration File

You need to setup the proper permissions for ESX for it to handle your server

```
add_ace resource.esx command.add_ace allow
add_ace resource.esx command.add_principal allow
add_ace resource.esx command.remove_principal allow

# Setup Group Inhereances
add_principal group.user builtin.everyone

add_principal group.donator_level_1 group.user
add_principal group.donator_level_2 group.donator_level_1
add_principal group.donator_level_3 group.donator_level_2

add_principal group.dev_level_1 group.user
add_principal group.dev_level_2 group.dev_level_1

add_principal group.staff_level_1 group.user
add_principal group.staff_level_2 group.staff_level_1
add_principal group.staff_level_3 group.staff_level_2
add_principal group.staff_level_4 group.staff_level_3
add_principal group.staff_level_5 group.staff_level_4
add_principal system.console group.staff_level_5
```
