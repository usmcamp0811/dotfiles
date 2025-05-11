<template>
  <footer class="absolute bottom-0 left-0 right-0 w-full z-9">
    <div
      class="flex w-full p-2"
      :class="{
        'justify-start': $slidev.configs.globalBottomPosition === 'left',
        'justify-end': !$slidev.configs.globalBottomPosition,
      }"
    >
      <div
        class="flex flex-col gap-2 bg-light-background dark:bg-dark-background bg-opacity-60 p-2 rounded-md"
      >
        <span class="text-sm"
          ><logos-bluesky class="mr-1" />@matt-camp.com</span
        >
        <div class="flex items-center gap-2">
          <img
            src="https://cdn.bsky.app/img/avatar/plain/did:plc:43gfod5fxbpt4s526s24o34w/bafkreihwhfjh7gsz73cquxvjynjs5y2xwnkkdlnjeiqbhera3jvmwpu74q@jpeg"
            class="w-3 h-3"
          />
          <span class="text-sm">aicampground.com</span>
        </div>
      </div>
    </div>
    <!-- <div class="border-bar"></div> -->
  </footer>
</template>

<style>
.border-bar {
  @apply h-0.5 w-full mb-1 bg-accent;
  box-shadow: 0 0 3px 0.5px var(--accent);
}
</style>
