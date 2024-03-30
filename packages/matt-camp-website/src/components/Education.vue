<template lang="html">
  <div>
    <div class="resume-item d-flex flex-column flex-md-row mb-5">
        <div class="resume-content mr-auto">
            <a href="/#/resume" @click="myeducation = true" ><h3 class="mb-0 degree">{{ schools.degree }}</h3></a>
            <div class="subheading mb-3">{{ schools.school }}</div>
        </div>
        <div class="resume-date text-md-right">
            <span class="text-primary">{{ schools.grad_dt }}</span>
        </div>
    </div>
        <!-- The Modal -->
    <q-dialog v-model="myeducation">
      <q-card v-bind:class="schools.school" style="width: 700px; max-width: 70%; max-height: 70%">
        <q-img v-bind:src="require('assets/resume/' + schools.image)" basic></q-img>
      </q-card>
    </q-dialog>

  </div>
</template>

<script>
export default {
  name: 'Education',
  props: {
    schools: null
  },
  data () {
    return {
      myeducation: false
    }
  },
  methods: {
  }
}
</script>

<style lang="css">
.mb-0 {
  font-weight: bold;
}
a {
  text-decoration: none;
}
</style>
