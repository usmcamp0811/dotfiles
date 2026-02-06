---
layout: top-title-two-cols
color: dark
columns: is-9
---

:: title ::

## Traditional Approaches

:: left ::

<div class="text-sm leading-relaxed">
Before Nix, teams used tools like:

<ul class="list-disc ml-4 mt-2">
  <li>✍️ <strong>Style guides</strong> — Suggestions on folder structure and naming, but not enforced or reproducible.</li>
  <li>🛠️ <strong>Chef / Puppet / Ansible</strong> — Automate config, but often require scripting glue and deep tribal knowledge.</li>
  <li>🔧 <strong>Shell scripts and golden images</strong> — Fast to set up, but impossible to maintain at scale.</li>
  <li>🪢 <strong>Follow README(s)</strong> — "Run these 17 commands in order and hope nothing breaks."</li>
</ul>

These tools stack on top of traditional operating systems and their package managers, which:

- <span v-mark.underline.orange>Don’t guarantee state</span>
- <span v-mark.underline.orange>Depend on mutable files</span>
- <span v-mark.underline.orange>Drift over time without notice</span>

</div>

:: right ::

<div class="flex justify-center items-end h-full pb-6">
  <img src="/assets/stack-of-tools.jpg" class="rounded shadow-lg max-w-[300px]" />
</div>

:: default ::

<StickyNote color="amber-light" textAlign="left" width="180px" v-drag="[720,370,180,180,-8]">
<span style="font-family: 'Comic Sans MS', 'Patrick Hand', cursive;">
Hey! You're new here.  
Go find the README.  
Set up your dev env.  
It's... a journey.  
Ping me if you survive. 😅
</span>
</StickyNote>

<!--
This is why we have tools like Docker, we just build everything from a known state and cross our fingers. But even this is flawed because then we are dependent on golden images and its difficult to compose tools in one image with another.
-->
