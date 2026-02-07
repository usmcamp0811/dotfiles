<template>
<q-layout view="hHh Lpr lff" class="shadow-2 rounded-borders">
  <div class="q-pa-md">
    <ResumeSideBar></ResumeSideBar>
    <q-page-container>
      <q-page padding>
        <section class="resume-section p-3 p-lg-5 d-flex d-column" id="about">
            <div class="my-auto">
                <h1 class="mb-0">Matthew
                    <span class="text-primary">Camp</span>
                </h1>
                <div class="subheading mb-5">
                    <div>
                        Huntsville, Alabama ·
                    <a href="mailto:name@email.com">matt@campmail.org</a>
                    </div>
                    <span class="social">
                        <a href="https://www.linkedin.com/in/matthewjcamp/"> <i class="fab fa-linkedin-in"></i></a>
                        <a href="https://github.com/usmcamp0811"><i class="fab fa-github"></i></a>
                    </span>
                </div>
            </div>
        </section>

        <section class="resume-section p-3 p-lg-5 d-flex justify-content-center" id="experience">
          <div class="w-100">
            <h2 class="mb-5">Experience</h2>
            <Experience v-for="jobs in experience" :key="jobs" :job=jobs></Experience>
          </div>
        </section>

        <section class="resume-section p-3 p-lg-5 d-flex flex-column" id="education">
            <div class="my-auto">
                <h2 class="mb-5">Education</h2>
                <Education v-for="school in education" :key="school" :schools=school></Education>
            </div>
        </section>
      </q-page>
    </q-page-container>
  </div>
</q-layout>
</template>

<script>
import ResumeSideBar from '../components/resume-sidebar.vue'
import Experience from '../components/Experience.vue'
import Education from '../components/Education.vue'
import Resume from '../assets/resume.json'

export default {
  name: 'resume',
  components: {
    ResumeSideBar,
    Experience,
    Education
  },
  data () {
    return {
      resume: Resume,
      experience: Resume['jobs'],
      education: Resume['education']
    }
  },
  mounted () {
    console.log(Resume['education'])
  }
}
</script>

<style>
h1 {
  font-size: 6rem;
  line-height: 5.5rem;
}

h2 {
  font-size: 3.5rem;
}

.subheading {
  text-transform: uppercase;
  font-weight: 500;
  font-family: 'Saira Extra Condensed', serif;
  font-size: 1.35rem;
}

.list-social-icons a {
  color: #495057;
}

.list-social-icons a:hover {
  color: #F05824;
}

.list-social-icons a .fa-lg {
  font-size: 1.75rem;
}

.list-icons {
  font-size: 3rem;
}

.list-icons .list-inline-item i:hover {
  color: #F05824;
}
</style>
