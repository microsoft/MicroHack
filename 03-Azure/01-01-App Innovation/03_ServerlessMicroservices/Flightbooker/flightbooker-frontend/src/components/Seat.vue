

<template>
  <div class="circle" 
  @mouseover.native="hover = true" 
  @mouseleave.native="hover =false" 
  v-bind:style="[ 
    hover ? {'background-color': selectedColor} : '',
    seat.status == 'selected' ? {'background-color':selectedColor}: '',
    seat.status == 'booked' ? {'background-color': bookedColor, 'opacity': 0.5}: '',
    ]"
  @click.native="selectSeat"
  > 
    <p> {{ seat.name }} </p>
  </div>

</template>

<script>
  import {bookSeat} from "@/services/BookingService";

  export default {
    props: {
      seat: Object
    },
    data() {
      return {
        hover: false,
        selectedColor: '#4AAE9B' ,
        bookedColor: 'aliceblue',
      };
    },

    methods: {
      selectSeat: function() {
        if (this.seat.status == 'free'){
          this.seat.status = 'selected';
          this.$store.dispatch('count', 1);
          this.$store.dispatch('add', this.seat.name);
          bookSeat(this.$store.state.seatList)
        }
        else if (this.seat.status =='selected'){
          this.seat.status = 'free';
          this.$store.dispatch('count', -1);
          this.$store.dispatch('remove', this.seat.name);
          bookSeat(this.$store.state.seatList)
        }
      },
    }
  }
</script>

<style scoped>
.item {
  margin-top: 2rem;
  display: flex;
}
.circle {
  width: 50px;
  height: 50px;
  line-height: 50px;
  border-radius: 50%;
  font-size: 20px;
  color: #000;
  text-align: center;
  background: #fff;
  border: 2px solid rgb(0,0,0);
  cursor:pointer;
}


</style>
