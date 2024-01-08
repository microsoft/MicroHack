<template>  
    <div class="container">
    <Seat
    v-for="seat in seatList"
    :seat ="seat"
    :key="seat.name">

    </Seat>
    </div>


</template>

<script >
import Seat from './Seat.vue';
  
  export default {
    components: {
      Seat,
    },
    computed: {
      seatList(){
        return this.$store.state.seatList
      }
    },
    mounted(){
      this.$store.dispatch("getSeats"); 
    }
  }
  </script>

  <style>
    .container {
      display: grid;
      grid-template-columns: 52px 52px 52px;
      grid-template-rows: 60px 60px 60px;
      grid-auto-columns: 52 px;
      grid-auto-rows: 60px;
      justify-items: center;
      align-items: center;
      justify-content: start;
    }

    .seat{
      justify-self: start;
    }
  </style>
