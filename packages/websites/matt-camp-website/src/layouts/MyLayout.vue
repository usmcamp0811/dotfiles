<template>
  <q-layout view="lHh Lpr lFf">
    <q-header>
      <q-toolbar class='mytopnavbar'>
        <q-avatar class="matt-text">
          <img src="~assets/headlogo.png" text="Matt Camp">
        </q-avatar>

        <q-toolbar-title>
          <a class="matt-text" href="#">MattCamp</a>
        </q-toolbar-title>
      </q-toolbar>
    </q-header>

    <q-page-container>
      <router-view />
    </q-page-container>
  </q-layout>
</template>

<script>
import { openURL } from 'quasar'

export default {
  name: 'MyLayout',
  data () {
    return {
    }
  },
  methods: {
    openURL
  }
}
</script>

<style>
@import url('https://fonts.googleapis.com/css?family=Orbitron|Sunflower:300');
@import url('https://fonts.googleapis.com/css?family=Exo+2');

.mytopnavbar{
    background: #1C7297;
    line-height: 50px;
    font-family: 'Sunflower', sans-serif;
    font-size: 1.1rem;
    text-transform: capitalize;
}

h3{
    font-family: 'Orbitron', sans-serif;
    font-weight: 400;
    font-stretch: extra-condensed;
    color: #343a40;
}

.q-toolbar__title{
    font-size: 1.7rem;
    padding-right: 0rem;
    padding-left: 0.5rem;
    padding-top: 10px;
    font-family: 'Orbitron', sans-serif;
    font-weight: 500;
    font-stretch: extra-condensed;
}

.matt-text{
  text-decoration: none;
  color: inherit;
}

.q-page-container{
    padding-top: 60px;
    background: white;
}
</style>
