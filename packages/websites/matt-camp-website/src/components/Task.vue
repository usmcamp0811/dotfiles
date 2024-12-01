<template lang="html">
  <div>
    <div class="resume-item d-flex flex-column flex-md-row mb-5">
        <div class="resume-content mr-auto">
            <a href="" v-bind:data-target="'myModal' + schools.degree" data-toggle="modal"><h3 class="mb-0 degree">{{ schools.degree }}</h3></a>
            <div class="subheading mb-3">{{ schools.school }}</div>
        </div>
        <div class="resume-date text-md-right">
            <span class="text-primary">{{ schools.grad_dt }}</span>
        </div>
    </div>

        <!-- The Modal -->
    <div class="modal" v-bind:id="'myModal' + schools.degree">
        <div class="modal-dialog modal-lg">
                <img v-bind:src="'/resume/img/' + schools.image">
        </div>
    </div>
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
    }
  },
  mounted () {
  }
}
</script>

<style lang="css">

</style>
