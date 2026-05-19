# Setup Guide

For proper installation of [Abyss](https://aumgupta.github.io/abyss-jellyfin/), follow the exact steps mentioned below.

<!-- Win -->
<details>
<summary><h2>Windows</h2></summary>

Download the latest `abyss-setup-vX.X.X.exe` from the [Releases](https://github.com/AumGupta/abyss-jellyfin/releases/latest) page and run it, a command prompt screen will pop up:

> <img src="docs/assets/images/setup/e1.png" style="width:50%;"/>


## 1. Installation

1. Type `1` and press `ENTER`.
> <img src="docs/assets/images/setup/i1.png" style="width:50%;"/>

2. Press `ENTER` to default to server url as `localhost:8096` or type server URL.
> <img src="docs/assets/images/setup/i2.png" style="width:50%;"/>
>
> [!NOTE]
> As of now the setup works on the same machine as your server.

3. Enter your Jellyfin admin username and password (you get 3 tries for typing the correct password).
> <img src="docs/assets/images/setup/i3.png" style="width:50%;"/><img src="docs/assets/images/setup/i4.png" style="width:50%;"/>

5. **DONE**. Your final screen should look like this, make sure you follow the `Next steps` shown on your screen at the end of setup.
> <img src="docs/assets/images/setup/i5.png" style="width:50%;"/>

***

<details>
<summary><h2>Uninstallation</h2></summary>

1. Type `2` and press `ENTER`.
> <img src="docs/assets/images/setup/u1.png" style="width:50%;"/>

2. Follow steps **2** and **3** of Installation section 

3. **DONE**. Your final screen should look like this, make sure you follow the `Next steps` shown on your screen at the end of setup.
> <img src="docs/assets/images/setup/u2.png" style="width:50%;"/>
</details>
</details>

<!-- Linus -->
<details>
<summary><h2>Linux & MacOS</h2></summary>

Download the latest **`abyss-setup-vX.X.X.sh`** from the [Releases](https://github.com/AumGupta/abyss-jellyfin/releases/latest) page and run it:

```bash
chmod +x abyss-setup-vX.X.X.sh
sudo ./abyss-setup-vX.X.X.sh
```

> ## NOTE
> Requires `curl` and `python3`, which are available by default on most Linux distributions.

</details>

<!-- Docker -->

<details>
<summary><h2>Docker</h2></summary>

> as Docker containers are ephemeral, modifications made inside them are usually destroyed when you update your container's image. below are **two methods** depending on which image you use:


<details>
<summary><h3>Method 1: Automated Init Script (recommended for <code>linuxserver/jellyfin</code>)</h3></summary>

The `linuxserver/jellyfin` image supports custom initialization scripts. On every container start, [`abyss-spotlight.sh`](scripts/docker/abyss-spotlight.sh) installs the **full theme** (all CSS under `/abyss/`), **Spotlight** (home banner + chunk patch), and the **touch** helper script.

**1. Install the init script**

```bash
mkdir -p ./jellyfin/config/custom-cont-init.d
curl -fsSL -o ./jellyfin/config/custom-cont-init.d/abyss-spotlight.sh \
  https://raw.githubusercontent.com/lucidsleeping/abyss-jellyfin-glassmorphic/main/scripts/docker/abyss-spotlight.sh
chmod +x ./jellyfin/config/custom-cont-init.d/abyss-spotlight.sh
```

**2. Docker Compose**

```yaml
services:
  jellyfin:
    image: lscr.io/linuxserver/jellyfin:latest
    environment:
      # Optional — auto-apply Custom CSS on startup
      - JELLYFIN_URL=http://127.0.0.1:8096
      - ABYSS_ADMIN_USER=your_admin
      - ABYSS_ADMIN_PASSWORD=your_password
      # Optional — use your fork (default: lucidsleeping/abyss-jellyfin-glassmorphic)
      # - ABYSS_REPO=lucidsleeping/abyss-jellyfin-glassmorphic
      # - ABYSS_BRANCH=main
    volumes:
      - ./jellyfin/config:/config
      - ./jellyfin/config/custom-cont-init.d:/custom-cont-init.d
      # Optional — install from a local clone instead of GitHub
      # - ./abyss-jellyfin-glassmorphic:/abyss-source:ro
    # Optional local source:
    # environment:
    #   - ABYSS_LOCAL_DIR=/abyss-source
```

**3. Custom CSS**

Either set `ABYSS_ADMIN_USER` / `ABYSS_ADMIN_PASSWORD` so the script applies this via API, or paste manually in **Dashboard > General > Custom CSS**:

```css
@import url('/web/abyss/abyss-bundle.css');
```

**4. Restart** and check logs: `docker logs jellyfin 2>&1 | grep abyss`

Verify theme: `http://YOUR_SERVER:8096/web/abyss/styles/abyss-layout.css`  
Verify Spotlight: home page shows the Continue Watching hero banner.

</details>


<details>
<summary><h3>Method 2: Interactive setup (For <code>jellyfin/jellyfin</code> and others)</h3></summary>

> ## NOTE
> This will work for all jellyfin docker images including:
> * jellyfin/jellyfin 
> * linuxserver/jellyfin
> * ghcr.io/hotio/jellyfin

Download the latest **`abyss-setup-vX.X.X.sh`** from the [Releases](https://github.com/AumGupta/abyss-jellyfin/releases/latest)

Copy it to the mounted config folder for your jellyfin container

Enter the container using the following command:

```bash
docker exec -it {container_name} bash
```
> Replace {container_name} with the name or id of your jellyfin container

Then run the following commands:

```bash
chmod +x abyss-setup-vX.X.X.sh
./abyss-setup-vX.X.X.sh
```
> Make sure to run these from within the container
> You have to be in the container as the root user

> ## NOTE
> Requires `curl` and `python3`, which are available by default on most Linux distributions.
</details>

</details>


<!-- Manual -->
<details>
<summary><h2>Manual Setup</h2><br>If you prefer not to use the installers, follow these steps to manually install Abyss with the Spotlight feature.</summary>

## 1. Apply Abyss CSS

Go to:

**Dashboard > Branding > Custom CSS**

Paste:

```css
@import url('https://cdn.jsdelivr.net/gh/AumGupta/abyss-jellyfin@main/abyss.css');
```

Save.

## 2. Set Theme to Dark

Go to:

**Settings > Display**

* Set **Theme** to **Dark**

> Abyss requires the Dark base theme to display correctly.


## 3. Configure Home Sections (Recommended)

Go to:

**Settings > Home**

Arrange sections in this exact order:

1. Continue Watching
2. Next Up
3. My Media
4. Recently Added


## 4. Install Spotlight (Manual Injection)

### Step 4.1: Locate your Jellyfin web directory

#### Typical locations:
- **Windows** 
  - `C:\Program Files\Jellyfin\Server\jellyfin-web\`
  - `C:\Program Files (x86)\Jellyfin\Server\jellyfin-web`
  - `C:\ProgramData\Jellyfin\Server\jellyfin-web`
- **Linux (native packages)**
  - `/usr/share/jellyfin/web`
  - `/usr/lib/jellyfin/web`
  - `/var/lib/jellyfin/web`
  - `/opt/jellyfin/web`
- **MacOS (Homebrew (intel and apple Silicon))**
  - `/usr/local/share/jellyfin/web`
  - `/opt/homebrew/share/jellyfin/web`
  - `/opt/homebrew/opt/jellyfin/web`
  - `/usr/local/opt/jellyfin/web`
- **MacOS (App bundle)**
  - `/Applications/Jellyfin.app/Contents/Resources/jellyfin-web`
  - `$HOME/Applications/Jellyfin.app/Contents/Resources/  - jellyfin-web`
  - `/Applications/Jellyfin.app/Contents/Resources/web`
  - `$HOME/Applications/Jellyfin.app/Contents/Resources/web`
- **Docker (jellyfin/jellfin (*official image*))** 
  - `/jellyfin/jellyfin-web`
    > Note: this is the path inside the container, not on the host. 

### Step 4.2: Create folders

Inside `jellyfin-web`, create:

```
/ui
```

### Step 4.3: Download required files

Download these files from the repo:

* [`scripts/spotlight/spotlight.html`](https://github.com/AumGupta/abyss-jellyfin/blob/main/scripts/spotlight/spotlight.html)
* [`scripts/spotlight/spotlight.css`](https://github.com/AumGupta/abyss-jellyfin/blob/main/scripts/spotlight/spotlight.css)
* [`scripts/spotlight/home-html.chunk.js`](https://github.com/AumGupta/abyss-jellyfin/blob/main/scripts/spotlight/home-html.chunk.js)

Place them in:

```
jellyfin-web/ui/
```

### Step 4.5: Patch Jellyfin home screen

1. In `jellyfin-web`, find a file like:

```
home-html.*.chunk.js
```
> (* will be a string of random characters like `home-html.83458cf8d6dc173356g4.chunk`)

2. **Create a backup** of this file: Simply copy the orginal file somewhere for your backup.

3. Replace the original file with: Copy content from `home-html.chunk.js (from /ui)` to the `home-html.*.chunk.js` file you found in `./jellyfin-web/`.

## 5. Restart Jellyfin

Restart your Jellyfin server.

## 6. Final Steps

* Clear browser cache
* Hard refresh (**Ctrl + F5**)
* Restart Jellyfin Media Player (if using desktop app)

> ## NOTE
> * The Spotlight feature requires modifying Jellyfin’s web files
> * Updates to Jellyfin may overwrite these changes
> * If something breaks, restore your `.bak` file


## Tip

Enable:

**Settings > Display > Show Backdrops**

for the best visual experience.

## Customisation

You can tweak colors, radius, and more here:
[https://aumgupta.github.io/abyss-jellyfin/](https://aumgupta.github.io/abyss-jellyfin/)


</details>


<details>
<summary><h2>Plugin Support</h2><br>If you use additional plugins, like <em>Jellyfin Enhanced</em>, <em>Media Bar Enhanced</em>, etc, then you can import it's <code>abyss-*css</code> override file.</summary>

Just copy the plugin specific import from the list and paste below the `@import` line of `abyss.css` in a series:

```css
@import url('https://cdn.jsdelivr.net/gh/AumGupta/abyss-jellyfin@main/abyss.css');

[PASTE PLUGIN SPECIFIC @IMPORT HERE]
```

> NOTE:
> These are version specific overrides and need maintenance. It's assured that `abyss-*css` overrides will be updated as plugins evolve, but newer versions of plugins might lead to delayed updates to these override files.

### 1. Jellyfin Enhanced `v11.3.0.0`

```css
@import url('https://cdn.jsdelivr.net/gh/AumGupta/abyss-jellyfin@main/styles/abyss-je.css');
```

### 2. Media Bar Enhanced `v1.9.0.0`
```css
@import url('https://cdn.jsdelivr.net/gh/AumGupta/abyss-jellyfin@main/styles/abyss-mbe.css');
```

</details>