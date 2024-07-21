<template>
<q-layout view="hHh Lpr lff" class="shadow-2 rounded-borders">
  <div class="q-pa-md my-body">
    <ResumeSideBar></ResumeSideBar>
    <q-page-container class="page-container">
        <section class="resume-section" id="about">
            <div class="my-auto">
                <h1 class="bold-text">Matthew
                    <span class="text-primary">Camp</span>
                </h1>
                <div class="subheading mb-5">
                    <div>
                        Huntsville, Alabama ·
                    <a href="mailto:matt@matt-camp.com">matt@matt-camp.com</a>
                    </div>
                    <span class="social">
                        <a href="https://www.linkedin.com/in/matthewjcamp/"><q-icon name="fab fa-linkedin-in" /></a>
                        <a href="https://github.com/usmcamp0811"><q-icon name="fab fa-github" /></a>
                        <a href="https://gitlab.com/usmcamp0811"><q-icon name="fab fa-gitlab" /></a>
                        <a href="https://blog.aicampground.com/post/index.xml"><q-icon name="fas fa-rss" /></a>
                    </span>
                </div>

                <p>{{ profile }}</p>
                <ul>
                  <li v-for="bullet in profile_bullets" :key="bullet" :bullet=bullet>
                    {{ bullet }}
                  </li>
                </ul>
            </div>
        </section>

        <section class="resume-section" id="experience">
          <div class="w-100">
            <h2 class="mb-5">Experience</h2>
            <Experience v-for="jobs in experience" :key="jobs" :job=jobs></Experience>
          </div>
        </section>

        <section class="resume-section" id="education">
            <div class="my-auto">
                <h2 class="mb-5">Education</h2>
                <Education v-for="school in education" :key="school" :schools=school></Education>
            </div>
        </section>

        <section class="resume-section" id="skills">
          <div class="my-auto">
              <h2 class="mb-5">Skills</h2>
              <div class="columwrapper">
                  <ul v-bind:class="'column-' + column.index" v-for="column in skills" :key="column">
                    <li v-for="item in column.skill" :key="item">{{ item }}</li>
                  </ul>
              </div>
          </div>
        </section>

        <section class="resume-section" id="awards">
            <div class="my-auto">
                <h2 class="mb-5">Awards &amp; Certifications</h2>
                <img src="~/assets/resume/ribbonstackonly.png" id="ribbonstack" usemap="#mystack">
                <map name="mystack">
                    <area target="" alt="Navy &amp; Marine Corps Commendation Medal" title="Navy &amp; Marine Corps Commendation Medal" @click="myModalNavyComm = true"  href="#" coords="152,0,299,42" shape="rect">
                    <area target="" alt="Combat Action Ribbon" title="Combat Action Ribbon" @click="myModalFallujah = true" href="#" coords="150,79,2,44" shape="rect">
                    <area target="" alt="Iraqi Campaign Ribbon" title="Iraqi Campaign Ribbon" @click="myModalFallujah = true" href="#" coords="304,124,151,83" shape="rect">
                    <area target="" alt="Selected Marine Corps Reserve Medal" title="Selected Marine Corps Reserve Medal" coords="447,82,300,44" shape="rect">
                    <area target="" alt="National Defense Ribbon" title="National Defense Ribbon" coords="4,83,149,120" shape="rect">
                    <area target="" alt="Navy Unit Commendation (NUC)" title="Navy Unit Commendation (NUC)" coords="300,81,155,45" shape="rect">
                    <area target="" alt="Global War on Terrorism Expeditionary Medal" title="Global War on Terrorism Expeditionary Medal" coords="306,86,446,120" shape="rect">
                    <area target="" alt="Global War on Terrorism Service Medal" title="Global War on Terrorism Service Medal" coords="4,125,147,161" shape="rect">
                    <area target="" alt="Sea Service Ribbon" title="Sea Service Ribbon" coords="155,126,298,161" shape="rect">
                    <area target="" alt="Armed Forces Reserve Medal" title="Armed Forces Reserve Medal" coords="305,127,449,161" shape="rect">
                </map>

            </div>
        </section>

        <q-dialog v-model="myModalFallujah">
          <q-card class="fallujah-pic">
            <q-img :src="require('assets/resume/meinfallujah.jpg')" class="fallujah" usemap="#palehorse"></q-img>
            <map name="palehorse">
                <area target="" alt="PFC Matthew Camp" title="PFC Matthew Camp" href="" coords="131,656,130" shape="circle">
            </map>
          </q-card>
        </q-dialog>

        <q-dialog v-model="myModalNavyComm">
          <q-card class="navcom">
            <q-img :src="require('assets/resume/NavyComm.jpeg')" basic></q-img>
          </q-card>
        </q-dialog>
    </q-page-container>
  </div>
</q-layout>
</template>

<script>
import ResumeSideBar from '../components/resume-sidebar.vue'
import Experience from '../components/Experience.vue'
import Education from '../components/Education.vue'
import Resume from '../assets/resume/resume.json'

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
      education: Resume['education'],
      profile: Resume['profile'],
      profile_bullets: Resume['profile_bullets'],
      skills: [],
      myModalFallujah: false,
      myModalNavyComm: false
    }
  },
  computed: {
  },
  mounted () {
    this.skills = this.reshape(Resume['skills'], 3)
  },
  methods: {
    reshape (array, n) {
      // reshape 1D array into MxN array.;
      // n: numbero f columns in array;
      var i = 0,
        temp = [],
        len = array.length * (1 / n),
        col = 0
      while (i < array.length) {
        temp.push({ 'index': col += 1,
          'skill': array.slice(i, i += len) })
      }
      console.log(temp)
      return temp
    }
  }
}
</script>

<style>
.my-body {
  font-family: -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,"Helvetica Neue",Arial,sans-serif,"Apple Color Emoji","Segoe UI Emoji","Segoe UI Symbol";
  font-size: 1rem;
  font-weight: 400;
  line-height: 1.5;
  color: #212529;
  text-align: left;
  padding-left: 3rem;
  padding-right: 3rem;
}
.page-container {
  max-width: 100%;
  overflow-x: hidden;
}
.fallujah-pic {
  width: 700px;
  max-width: 70%;
  max-height: 70%
}

.navcom {
  width: 700px;
  max-width: 70%;
  max-height: 70%
}

h1 {
  font-size: 6rem;
  line-height: 5.5rem;
}

h2 {
  font-size: 3.5rem;
}

.h3, h3 {
  font-size: 1.75rem;
  line-height: 1.2;
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

.bold-text{
  font-weight: bold;
}

section.resume-section .resume-item .resume-date {
  min-width: none;
}

section.resume-section {
  min-height: 100vh;
  margin-top: auto;
  margin-bottom: auto;
}

.text-primary {
  color: #F05824 !important;
}

.social [class*="fab fa-"] {
    background-color: #333;
    border-radius: 30px;
    color: #fff;
    display: inline-block;
    height: 30px;
    line-height: 30px;
    margin: auto 3px;
    width: 30px;
    font-size: 15px;
    text-align: center;
}

.social [class*="fas fa-"] {
    background-color: #333;
    border-radius: 30px;
    color: #fff;
    display: inline-block;
    height: 30px;
    line-height: 30px;
    margin: auto 3px;
    width: 30px;
    font-size: 15px;
    text-align: center;
}

.social a:hover [class*="fab fa-"]{
  background-color: #F05824;
}

.fa-twitter:hover {
    background-color: #46c0fb;
}

#ribbonstack{
  height: 200px;
  max-width: 90vw;
}

.fallujah{
  max-width: 75vw;
  max-height: 75vh;
}

h1,
h2,
h3,
h4,
h5,
h6 {
    font-family: 'Orbitron', sans-serif;
    font-weight: 400;
    font-stretch: extra-condensed;
    color: #343a40;
}

p {
    margin-top: 0;
    margin-bottom: 1rem;
}

@media (max-width: 1080px) {
    h1 {
    font-size: 4.5rem;
    line-height: 5.5rem;
  }
}

@media (max-width: 475px) {
    h1 {
    font-size: 3.0rem;
    line-height: 3.5rem;
  }
  .h3, h3 {
    font-size: 1.1rem;
    line-height: 1.0;
  }
  h2 {
    font-size: 2.2rem;
  }
  .subheading {
    font-size: 1rem;
  }
  section.resume-section {
    padding-left: 1rem !important;
    padding-right: 1rem !important;
    padding-top: 4rem;
  }
  #ribbonstack{
    height: 100px;
    max-width: 65vw;
  }
}

@media (min-width: 768px) {
  section.resume-section {
    min-height: 100vh;
  }
  section.resume-section .resume-item .resume-date {
    min-width: 18rem;
  }
}

@media (min-width: 992px) {
  section.resume-section {
    padding-top: 3rem !important;
    padding-bottom: 3rem !important;
  }
}

div.q-page-container:nth-child(2) {
    padding-top: 0px !important;
    background: white;
}

.q-pa-md {
  padding-top: 0px;
}

.mb-5, .my-5 {
   margin-bottom: 3rem !important;
}

a {
  text-decoration: none;
  color: #F05824;
}

.mb-0, .my-0 {
  margin-bottom: 0 !important;
}

.my-auto {
  box-sizing: border-box;
  display: block;
  float: none;
  line-height: 24px;
  position: static;
  z-index: auto;
  margin-bottom: auto !important;
  margin-top: auto !important;
  box-sizing: border-box;
  border-bottom: 1px solid #dee2e6;
}

section {
    min-height: 10em;
    display: flex;
    vertical-align: middle;
}
</style>
