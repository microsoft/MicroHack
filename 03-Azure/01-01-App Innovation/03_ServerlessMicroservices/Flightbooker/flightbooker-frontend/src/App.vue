<template>
  <header>
    <div class="wrapper">
      <Title></Title>
    </div>
  </header>

  <main>
    <div class="seatmap">
      <SeatMap></SeatMap>
    </div>
    <div>
      <Button @click="showModal" ></Button>
      <Modal v-show="isModalVisible"
      @close="closeModal" />

    </div>
    
    
  </main>

</template>

<script setup>
import Title from './components/Title.vue';
import SeatMap from './components/SeatMap.vue';
import Button from './components/Button.vue';
</script>

<script>
import Modal from './components/Modal.vue';
import {getAllSeats, bookSeat} from './services/BookingService.js';
  export default { 
    components: {
      Modal,
    },
    data() {
      return{
        isModalVisible: false,
        message: [],
      };
    },
    methods: {
      showModal() {
        this.isModalVisible=true;
      },
      closeModal(){
        this.isModalVisible = false;
        this.$store.state.seatList.forEach(seat => {
          if (seat.status == "selected"){
            seat.status="booked"
          }
        });
        this.$store.dispatch('resetCount');
        bookSeat(this.$store.state.seatList);
      },

    }

  }
</script>


<style scoped>
header {
  line-height: 1.5;
}
main {
  padding-top: 10px;
  padding-bottom: 10px;
}
.seatmap{
  padding-bottom: 10px;
}

 @media (min-width: 1024px) {
  header {
    display: flex;
    place-items: top;
    padding-right: calc(var(--section-gap) / 2);
  }

  header .wrapper {
    display: flex;
    place-items: flex-start;
    flex-wrap: wrap; 
  }
}
</style>

<style>
  html,body,button {
    font-family: Verdana, sans-serif;
  }
</style>
