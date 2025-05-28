---
theme: ./themes/slidev-theme-neversink
layout: image
image: /assets/blackboard-slide-bg.jpg
---

<link href="https://fonts.googleapis.com/css2?family=Titillium+Web:wght@300;600&display=swap" rel="stylesheet">

<div class="title-slide-container">
  <h1 class="title-big">BEYOND YAML:</h1>
  <svg class="drawn-underline" viewBox="0 0 400 20" preserveAspectRatio="none">
    <path d="M5 15 Q 200 25 395 15" stroke="#00bcd4" stroke-width="4" fill="none" stroke-linecap="round" />
  </svg>
  <img src="/assets/Nix_Snowflake_Logo.svg" class="nix-logo" />
  <h2>The Case for Nix as the Common Language of DevSecOps</h2>
  <img src="/assets/noyaml.png" class="noyaml" />
</div>

<style>
.title-slide-container {
  position: relative;
  display: flex;
  flex-direction: column;
  justify-content: center;
  height: 100%;
  padding: 1.4em 2em 0 5.5em;
}
.title-big {
  font-family: 'Titillium Web', sans-serif;
  font-size: 3.5rem;
  font-weight: 405;
  margin: 0;
  text-align: left;
}

h2 {
  font-family: 'Titillium Web', sans-serif;
  font-weight: 50;
  font-size: 2.20rem;
}

.drawn-underline {
  width: 70%;
  height: 1.0em;
  margin: -0.1em 0 0.1em;
}

.nix-logo {
  position: absolute;
  top: 4.75em;
  right: 6em;
  height: 10rem;
}
.noyaml {
  position: absolute;
  top: 1.5em;
  left: 1em;
  height: 9rem;
}
.no-gap .slidev-layout.image-left .image-container {
margin-left: 0 !important;
padding-left: 0 !important;
}

.no-gap .slidev-layout.image-left .content-container {
padding-left: 0 !important;
}

</style>

---
src: ./slides/beyond-yaml/problem-devsecops-today.md
---

---
src: ./slides/beyond-yaml/yaml-old-glue.md
---

---
src: ./slides/beyond-yaml/devsecops-req.md
---

---
src: ./slides/beyond-yaml/why-nix.md
---
