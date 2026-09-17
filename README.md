# FPGA-UART-Loopback--VHDL
A complete VHDL UART transceiver and loopback interface featuring 2-stage input synchronization, mid-bit oversampling, framing error detection, and an integrated FIFO buffer. The system can receive a UART frame, from a PC for example, and transmit it back. The UART frame used for this project is a simple 8N1 frame.


## The System:

<img width="1374" height="533" alt="image" src="https://github.com/user-attachments/assets/322cd246-daa8-414a-9325-9f4440c3ae58" />


## Features:

### Synchronizer

<img width="2280" height="524" alt="image" src="https://github.com/user-attachments/assets/c2089720-b97b-4a6d-baec-9f2c247ebe35" />

Because the FPGA does not know or have access to clock of the PC which sends the UART frames, if signals are received by the FPGA at the same time as its clock edge, metastability can be introduced meaning that the received signal can have an unsettled causing the circuit to act in unpredictable ways. By having the incoming signal go into two DFFs, it is allowed one clock period to settle to a '0' or '1' before being sent into the second DFF, therefore decreasing the risk of metastability occuring.


### 16x Oversampling

Oversampling is used so that the FPGA does not need to be in complete sync with exactly when the PC sends each bit. Of course a baud rate has to be agreed upon; this project uses a baud rate of 115200 bits per second. If the sample rate was simply 115200 baud, the FPGA could be out of time with when signals are sent and so framing errors and missed signals would occur. To solve this, the system samples at 16 times the baud rate. 16 * 115200 = 1843200 samples/second and so a 16x tick generator was implemented to give the receiver a one clock period tick to tell it to sample the serial input signal.

The FPGAs internal clock runs at 50MHz. 50MHz / 1843200 samples/second = 27.1267 clocks per sample. 4096 can be divided by 27.1267 to give approximately 151 which is good because that is an integer that added at each clock to a 13 bit register. Once the 13th bit of the register goes high, a tick is sent to the receiver controller before the 13th bit is set low again. This loop happens continuously while the system is running. this gives a tick on average every 27.1258 clocks (most of the time after 27 clocks but some times 28) which gives an error rate of 0.003%. The oversampling is used so that as soon as the received signal drops low (start bit), the FPGA can then be in sync with it. 

The oversampling is also useful because it can help to eliminate noise from messing with the receiver by sending false start bits and such. This is because when the signal is drawn low, the receiver can wait several ticks later to sample near the middle of the received bit to verify that it is actually a start bit and not signal noise or disruptions.


## The Receiver Controller

The Receiver Controller takes the incoming signal after it has been synchronized with the FPGAs clock domain and detects when a start bit occurs (signal drawn low), samples and stores the 8 data bits for outputting to the FIFO, and checks for framing errors by checking if a stop bit is received.

<img width="2720" height="1528" alt="image" src="https://github.com/user-attachments/assets/550cfcb7-daf3-4254-9036-bcd2e2fd1ff5" />


The asynchronous receiver uses a finite-state machine which has four states : IDLE, CHECK, RECEIVE and STOP.

- The IDLE state resets all of the counters (sample counter and bit counter). If the incoming signal goes low it goes to the CHECK state to see if it was actually a start bit or if it was noise.

- The CHECK state waits for the sample counter to reach 7 (Near the middle of the incoming UART bit) and samples the incoming signal again. If the signal is low, it continues to the RECEIVE state because it knows that the start bit signal was not due to noise. Otherwise, if the signal is high again, it returns to the IDLE state.

- The RECEIVE state then waits 16, 16x ticks before sampling each data bit ensuring the middle of each bit is sampled so that transitions between bits are not sampled. after all 8 data bits are sampled, the FSM goes to the STOP state.

- The STOP state checks if the signal is drawn high. If it is, it goes straight to the IDLE state. if not, it replaces receiver controller's the output byte with 0x3F which is the ASCII for ? and so a ? will be transmitted back to the PC because a framing error had occured. The FSM then goes back to the IDLE state.


### FIFO

The system uses an 8 bit wide, 4 words deep FIFO to store and read the data bytes coming into the UART loopback system. The FIFO acts as a sort of buffer incase of timing mismatch or transmission delays so that the receiver and transmitter do not need to be perfectly synchronized when receiving and transmitting frames. It sends out empty, almost empty, almost full and full flags to LEDs to act as a visual indicator to the user. The empty flag also goes the the Transmitter Controller to tell it when to stop reading from the FIFO.


### The Transmitter Controller

The transmitter controller takes the data byte at the read pointer's location in the FIFO, if the FIFO's empty flag is low. The data byte held in that location is then stored in a shift register and transmitted along with the start and stop bits to complete a full UART 8N1 frame. This is done at 115200 baud by counting the 16x baud tick created in the baud_tick_16x.vhd file 16 times before shifting the output to the next bit.

<img width="2320" height="1200" alt="image" src="https://github.com/user-attachments/assets/352354bc-9204-44d8-b8e2-98d2a9c6ced2" />

This is done with another FSM of only two states : IDLE and TRANSMIT.

- The IDLE state resets all of the counters and the shift register's bits to all 1s (no start bit). If the FIFO's empty flag goes low, the FSM transitions to the TRANSMIT state.

- The TRANSMIT state takes the data byte at the read pointer's location in the FIFO, stores it in a shift register and outputs the bits at 115200 baud. Once all 10 of the frame's bits are sent, it goes back to the IDLE state.
