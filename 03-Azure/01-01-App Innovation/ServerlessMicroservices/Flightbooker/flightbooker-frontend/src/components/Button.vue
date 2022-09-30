<template>
  <div>
    <button 
    class="button"
    :disabled="this.$store.state.selectedCount == 0"
    > 
    Book Seats</button>
  </div>
</template>

<script>
</script>

<style scoped>
    .button{
        width: 155px;
        height: 50px;
        border-radius: 12px;
        background-color:aliceblue;
        border: 2px solid #000;
        padding: 15 px 32 px;
        text-align: center;
        display: inline-block;
        font-size: 20 px;
        cursor: pointer;
        justify-content: start;
    }
    .button:hover{
        background-color: #000;
        color:#FFFF;
    }
    .button:disabled {
        opacity: 0.6;
        cursor: not-allowed;
    }
    .button:disabled:hover{
        background-color: aliceblue;
        color:rgb(200, 200, 200);
    }
</style>
