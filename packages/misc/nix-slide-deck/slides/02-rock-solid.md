--- layout: top-title-two-cols
color: dark
columns: is-9
src: ./slides/02-rock-solid.md 
---

:: title ::

# Rock-Solid Infrastructure Starts Here

:: default ::

<div class="bluf-box clear-both mt-8">
  <strong>BLUF:</strong> Nix isn’t another tool on sand — it’s the rock-solid foundation your entire software ecosystem.
</div>

:: left ::

<div class="text-sm leading-relaxed">
Most tools build <strong>on top</strong> of mutable, fragile foundations.  
Like building a house on sand, you're always one gust away from breakage.

Nix builds <strong>from the ground up</strong> on a cryptographic, content-addressed store, ensuring:

<ul class="list-disc ml-4 mt-2">
  <li>🪨 <strong>A solid, reproducible base</strong> — Every dependency, build input, and configuration is pinned. Your app builds the same today, tomorrow, and on any machine.</li>
  <li>🔄 <strong>Immutable builds</strong> — No surprises from "latest" or system drift. A build that worked once will always work again, byte-for-byte.</li>
  <li>🧱 <strong>Consistency across environments</strong> — From your laptop to CI to production, Nix ensures identical environments without "it works on my machine" bugs.</li>
</ul>
</div>

:: right ::

<div class="flex min-h-[350px] items-center justify-center">
  <img src="/assets/house_on_rock_and_sand.jpg" class="rounded shadow-lg max-w-[250px]" />
</div>

<!--
lazy build everything from source 
subsitutors 


taken artifact trust out of the equation 

crpto signed hashed artifacts and code
-->
