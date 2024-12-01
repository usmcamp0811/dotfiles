<template>
  <q-drawer
    v-model="drawer"
    :breakpoint="992"
    show-if-above
    content-class="resume-sidebar-color"
    id="side-drawer"
  >
    <div class="absolute-center">
      <a href="#about">
        <q-avatar size="160px" class="avatar-border">
          <q-avatar size="145px">
            <img src="../assets/resume/new_headshot.jpg">
          </q-avatar>
        </q-avatar>
      </a>

      <q-list v-for="(menuItem, index) in menuList" :key="index" class="list">
        <q-item clickable v-ripple class="list-item">
          <q-item-section>
            <a v-bind:href="menuItem.link" class="sidebar-text">{{ menuItem.label }}</a>
          </q-item-section>
        </q-item>
      </q-list>

    </div>
  </q-drawer>

</template>

<script>

export default {
  name: 'ResumeSideBar',
  data () {
    return {
      drawer: false,
      menuList: [
        {
          icon: 'inbox',
          label: 'About',
          link: '/#about',
          separator: true
        },
        {
          icon: 'send',
          label: 'Experience',
          link: '/#experience',
          separator: false
        },
        {
          icon: 'delete',
          label: 'Education',
          link: '/#education',
          separator: false
        },
        {
          icon: 'error',
          label: 'Skills',
          link: '/#skills',
          separator: true
        },
        {
          icon: 'feedback',
          label: 'Awards',
          link: '/#awards',
          separator: false
        },
        {
          icon: 'blog',
          label: 'Blog',
          link: 'https://blog.aicampground.com',
          separator: false
        }
      ]
    }
  }
}

</script>

<style>
@import url('https://fonts.googleapis.com/css?family=Saira+Extra+Condensed:100,200,300,400,500,600,700,800,900');
@import url('https://fonts.googleapis.com/css?family=Open+Sans:300,300i,400,400i,600,600i,700,700i,800,800i');

#side-drawer{
  width: 15rem;
  height: 100vh;
  color: #fff;
  text-align: center;
  position: fixed;
  top: 0;
  left: 0;
  display: flex;
  flex-direction: column;
  vertical-align: middle;
}
.resume-sidebar-color{
  background: #F05824 !important;
}

.list{
  text-align: center;

}
.list-item{
  border-radius: 60px;
  color: #fff;
  display: inline-block;
  height: 30px;
  line-height: 30px;
  margin: auto 3px;
  font-size: 30px;
  text-align: center;
  letter-spacing: .05rem;
  text-transform: uppercase;
  font-size: 1.1rem;
  font-family: 'Sunflower', sans-serif;
  font-weight: 400;
  font-stretch: extra-condensed;
}

.sidebar-text {
  color: rgba(255,255,255,.75);
  font-weight: 600;
  text-transform: uppercase;
}

.sidebar-text:hover, .sidebar-text:focus, .sidebar-text:active {
  color: #824027;
}

.avatar-border {
  background: rgba(255, 255, 255, 0.2);
}
</style>
