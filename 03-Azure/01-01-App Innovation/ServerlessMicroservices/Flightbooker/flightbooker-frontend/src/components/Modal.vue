<template>
    <div class="modal-backdrop">
        <div class="modal">
            <header class="modal-header">
                <slot name="header">
                    Booking receipt
                </slot>
            </header>

            <section class="modal-body">
                <slot name ="body">
                    You have booked the following seats:
                    <template v-for="seat in $store.state.seatList">
                        <li v-if="seat.status == 'selected'">
                            {{seat.name}}
                        </li>
                    </template> 
                    
                </slot>
            </section>

            <footer class="modal-footer">
                <slot name ="footer">
                    
                </slot>
                <button type="button" class="btn-ok" @click="close">OK</button>
            </footer>
        </div>
    </div>
  </template>
  
  <script>
    export default{
        name: 'Modal',
        components: {
            
        },
        data() {
            return{
            };
        },
  
        methods: {
            close: function(){
                this.$emit('close');
            }
            
        }
    }
  </script>
  
  <style scoped>
    .modal-backdrop {
        position: fixed;
        top: 0;
        bottom:0;
        left:0;
        right:0;
        background-color: rgba(0,0,0,0.3);
        display: flex;
        justify-content: center;
        align-items: center;
    }

    .modal {
        background: #FFFFFF;
        box-shadow: 2px 2px 20px 1px;
        overflow-x: auto;
        display: flex;
        flex-direction: column;
    }

    .modal-header,
    .modal-footer{
        padding: 15px;
        display: flex;
    }

    .modal-header {
        position: relative;
        border-bottom: 1px solid aliceblue;
        color: #000;
        justify-content:center;
        font-weight: normal;
        background: aliceblue;
    }

    .modal-footer {
        flex-direction:column;
        justify-content:flex-end;
    }

    .modal-body {
        position: relative;
        padding: 20px 10px;
    }

    .btn-ok {
        color:black;
        background: aliceblue;
        border: 2px solid #4AAE9B;
        border-radius:8px;
        padding: 5px;
        cursor: pointer;
        font-weight: normal;
    }
    .btn-ok:hover {
        background-color: #4AAE9B;
        color:#FFFFFF
    }
  </style>