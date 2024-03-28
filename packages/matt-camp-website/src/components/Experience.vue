<template lang="html">
  <div class="resume-item d-flex flex-column flex-md-row justify-content-between mb-5">
    <div class="resume-content">
      <h3 class="mb-0">{{ job.job_title }}</h3>
      <div class="subheading mb-3">{{ job.company || 'default value' }}</div>
      <p>{{ job.description || 'default value' }}</p>
    </div>
    <ul v-if="job.key_accomplishments.length > 0">
      <li v-for="accomplishment in job.key_accomplishments" :key="accomplishment">{{ accomplishment }}</li>
    </ul>
    <div class="resume-date text-md-right">
      <span class="text-primary">{{ job.dt_from || 'default value' }} - {{ job.dt_to || 'default value' }}</span>
    </div>
  </div>
</template>

<script>
export default {
  name: 'Experience',
  props: {
    job: null
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
.text-md-right {
  text-align: right !important;
}
</style>
