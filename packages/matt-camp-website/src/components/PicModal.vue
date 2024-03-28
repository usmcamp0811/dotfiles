<template>
  <div class="q-pa-md q-gutter-sm">
    <q-btn label="Card" color="primary" @click="card = true" ></q-btn>
    <q-dialog v-model="card">
      <q-card class="my-card">
        <q-img v-bind:src="pic_path" basic></q-img>
      </q-card>
    </q-dialog>
  </div>
</template>

<style>
.my-card {
  width: 500px;
  max-width: 50%;
  max-height: 50%
}
</style>

<script>
export default {
  name: 'PicModal',
  props: {
    pic_path: ''
  },
  data () {
    return {
      card: false
    }
  }
}
</script>
