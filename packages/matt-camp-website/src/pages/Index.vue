<template>
  <q-page class="flex flex-center">
    Hello World!

    <div class="q-pa-md q-gutter-sm">
      <q-btn label="Card" color="primary" @click="card = true" ></q-btn>
      <q-dialog v-model="card">
        <q-card class="my-card">
          <q-img src="../assets/resume/meinfallujah.jpg" basic></q-img>
        </q-card>
      </q-dialog>
    </div>
  </q-page>
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
  name: 'PageIndex',
  data () {
    return {
      card: false
    }
  }
}
</script>
