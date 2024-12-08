module vga_driver_to_frame_buf	(
	input 		          		CLOCK_50,
	//////////// SEG7 //////////
	output		     [6:0]		HEX0,
	output		     [6:0]		HEX1,
	output		     [6:0]		HEX2,
	output		     [6:0]		HEX3,
	//////////// KEY //////////
	input 		     [3:0]		KEY,
	//////////// LED //////////
	output		     [9:0]		LEDR,
	//////////// SW //////////
	input 		     [9:0]		SW,
	//////////// VGA //////////
	output		          		VGA_BLANK_N,
	output		     [7:0]		VGA_B,
	output		          		VGA_CLK,
	output		     [7:0]		VGA_G,
	output		          		VGA_HS,
	output		     [7:0]		VGA_R,
	output		          		VGA_SYNC_N,
	output		          		VGA_VS
);

// Turn off all displays.
assign	HEX0		=	7'h00;
assign	HEX1		=	7'h00;
assign	HEX2		=	7'h00;
assign	HEX3		=	7'h00;

// DONE STANDARD PORT DECLARATION ABOVE
/* HANDLE SIGNALS FOR CIRCUIT */
wire clk;
wire rst;

assign clk = CLOCK_50;
assign rst = SW[0];

wire [9:0]SW_db;

debounce_switches db(
.clk(clk),
.rst(rst),
.SW(SW), 
.SW_db(SW_db)
);

// VGA DRIVER
wire active_pixels; // is on when we're in the active draw space
wire frame_done;
wire [9:0]x; // current x
wire [9:0]y; // current y - 10 bits = 1024 ... a little bit more than we need

/* the 3 signals to set to write to the picture */
reg [14:0] the_vga_draw_frame_write_mem_address;
reg [23:0] the_vga_draw_frame_write_mem_data;
reg the_vga_draw_frame_write_a_pixel;
reg [9:0] current_y;
reg [9:0] current_x;

 

/* This is the frame driver point that you can write to the draw_frame */
vga_frame_driver my_frame_driver(
	.clk(clk),
	.rst(rst),

	.active_pixels(active_pixels),
	.frame_done(frame_done),

	.x(x),
	.y(y),

	.VGA_BLANK_N(VGA_BLANK_N),
	.VGA_CLK(VGA_CLK),
	.VGA_HS(VGA_HS),
	.VGA_SYNC_N(VGA_SYNC_N),
	.VGA_VS(VGA_VS),
	.VGA_B(VGA_B),
	.VGA_G(VGA_G),
	.VGA_R(VGA_R),

	/* writes to the frame buf - you need to figure out how x and y or other details provide a translation */
	.the_vga_draw_frame_write_mem_address(the_vga_draw_frame_write_mem_address),
	.the_vga_draw_frame_write_mem_data(the_vga_draw_frame_write_mem_data),
	.the_vga_draw_frame_write_a_pixel(the_vga_draw_frame_write_a_pixel)
);

reg [15:0]i;
reg [7:0]S;
reg [7:0]NS;
parameter 
	START 			= 8'd0,
	// W2M is write to memory
	W2M_INIT 		= 8'd1,
	W2M_COND 		= 8'd2,
	W2M_INC 			= 8'd3,
	W2M_DONE 		= 8'd4,
	// The RFM = READ_FROM_MEMOERY reading cycles
	RFM_INIT_START = 8'd5,
	RFM_INIT_WAIT 	= 8'd6,
	RFM_DRAWING 	= 8'd7,
	ERROR 			= 8'hFF;

parameter MEMORY_SIZE = 16'd19200; // 160*120 // Number of memory spots ... highly reduced since memory is slow
parameter PIXEL_VIRTUAL_SIZE = 16'd4; // Pixels per spot - therefore 4x4 pixels are drawn per memory location

/* ACTUAL VGA RESOLUTION */
parameter VGA_WIDTH = 16'd640; 
parameter VGA_HEIGHT = 16'd480;

/* Our reduced RESOLUTION 160 by 120 needs a memory of 19,200 words each 24 bits wide */
parameter VIRTUAL_PIXEL_WIDTH = VGA_WIDTH/PIXEL_VIRTUAL_SIZE; // 160
parameter VIRTUAL_PIXEL_HEIGHT = VGA_HEIGHT/PIXEL_VIRTUAL_SIZE; // 120

/*added param for blue background*/
parameter LIGHT_GRAY = 24'b101010101010101010101010;
parameter GREEN = 24'h00FF00;
parameter BLACK = 24'h000000;
parameter WHITE = 24'hFFFFFF;
parameter LIGHT_BLUE = 24'h00FFFF;

//All parameters for the Frog
parameter FROG_COLOR = 24'b000000010100100000100000;
reg [9:0] frog_x;
reg [9:0] frog_y;
reg [3:0] key_reg; 
parameter STEP_SIZE = 10'd20;


//ALL parameters for the cars
parameter RED_CAR = 24'hFF0000;
parameter BLUE_CAR = 24'h0000FF;
parameter PURPLE_CAR = 24'b100000000100000010000000;
parameter YELLOW_CAR = 24'hFFFF00;
parameter ORANGE_CAR = 24'b111111111010010100000000;
parameter PINK_CAR = 24'b111111111100000011001011;

reg[20:0] move_timer;
parameter MOVE_THRESHOLD = 21'd1500000;
reg[9:0] car_position_x[23:0];
reg[9:0] car_position_y[23:0];
reg[20:0] frog_move_timer;
reg win = 1'b0;
reg game_over;
 
 
always@(posedge clk or negedge rst) begin
  if (!rst) begin
    move_timer <= 18'd0;
	 //First road starting positions
	 car_position_x[0] <= 10'd0;
	 car_position_y[0] <= 10'd403;
	 car_position_y[1] <= 10'd403;
	 car_position_x[1] <= 10'd100;
	 car_position_x[2] <= 10'd300;
	 car_position_y[2] <= 10'd403;
	 car_position_y[3] <= 10'd403;
	 car_position_x[3] <= 10'd500;
	 
	 //Second road starting positions
	 car_position_x[4] <= 10'd20;
	 car_position_y[4] <= 10'd315;
	 car_position_y[5] <= 10'd315;
	 car_position_x[5] <= 10'd160;
	 car_position_x[6] <= 10'd340;
	 car_position_y[6] <= 10'd315;
	 car_position_y[7] <= 10'd315;
	 car_position_x[7] <= 10'd460;
	 
	 //Third road starting positions
    car_position_x[8] <= 10'd10;
    car_position_x[9] <= 10'd120;
    car_position_x[10] <= 10'd220;
    car_position_x[11] <= 10'd350;
    car_position_x[12] <= 10'd480;
	 car_position_y[8] <= 10'd230;
    car_position_y[9] <= 10'd230;
    car_position_y[10] <= 10'd230;
    car_position_y[11] <= 10'd230;
    car_position_y[12] <= 10'd230;
	 
	 //Fourth road starting positions
	 car_position_x[13] <= 10'd0;
    car_position_x[14] <= 10'd100;
    car_position_x[15] <= 10'd240;
    car_position_x[16] <= 10'd370;
    car_position_x[17] <= 10'd460;
	 car_position_y[13] <= 10'd141;
    car_position_y[14] <= 10'd141;
    car_position_y[15] <= 10'd141;
    car_position_y[16] <= 10'd141;
    car_position_y[17] <= 10'd141;
	 
	 //Fifth road starting positions
	 car_position_x[18] <= 10'd0;
    car_position_x[19] <= 10'd120;
    car_position_x[20] <= 10'd205;
    car_position_x[21] <= 10'd322;
    car_position_x[22] <= 10'd400;
	 car_position_x[23] <= 10'd480;
	 car_position_y[18] <= 10'd54;
    car_position_y[19] <= 10'd54;
    car_position_y[20] <= 10'd54;
    car_position_y[21] <= 10'd54;
    car_position_y[22] <= 10'd54;
	 car_position_y[23] <= 10'd54;
	 
  end else begin
  for(i = 0; i < 24; i= i + 1) begin
    if (move_timer >= MOVE_THRESHOLD) begin
	   move_timer <= 18'd0;
      car_position_x[i] <= car_position_x[i] + 10'd5;
		if (car_position_x[i] >= VGA_WIDTH) begin
		  car_position_x[i] <= 10'd0;
		end
	end else begin
	  move_timer <= move_timer + 1'b1;
	  end
	  end
	end
end

/* idx_location stores all the locations in the */
reg [14:0] idx_location;
wire move_left, move_right, move_up, move_down;
    assign move_left = ~KEY[1];  // Inverted because active low
    assign move_up = ~KEY[3];
    assign move_down = ~KEY[2];
    assign move_right = ~KEY[0];
	 
	 
parameter FROG_MOVE_THRESHOLD = 800000; // Adjust based on your clock speed and debouncing needs
	 
	 
always @(posedge clk or negedge rst) begin
    if (!rst) begin
        frog_x <= 10'd320;  // Reset frog to the center of the screen
        frog_y <= 10'd451;  // Reset frog to near the bottom of the screen
        frog_move_timer <= 21'd0;
    end else begin
	   if(win == 0) begin
        if (frog_move_timer >= FROG_MOVE_THRESHOLD) begin
            frog_move_timer <= 21'd0;  // Reset the timer when it reaches the threshold
            
            if (move_left) begin // Move left
                if (frog_x > STEP_SIZE) begin
                    frog_x <= frog_x - 1;
                end
            end

            if (move_up) begin // Move up
                if (frog_y > 5) begin
                    frog_y <= frog_y - 1;
                end
            end

            if (move_down) begin // Move down
                if (frog_y < (VGA_HEIGHT - STEP_SIZE)) begin
                    frog_y <= frog_y + 1;
                end
            end

            if (move_right) begin // Move right
                if (frog_x < (VGA_WIDTH - STEP_SIZE)) begin
                    frog_x <= frog_x + 1;
                end
            end
        end else begin
            frog_move_timer <= frog_move_timer + 1'b1;  // Increment the timer
        end 
    end
end
end

// Just so I can see the address being calculated
assign LEDR = idx_location;


always @(posedge clk or negedge rst) begin
  if(!rst) begin
	win <= 0;
  end else if(frog_y <= 30) begin
	win <= 1;
  end else begin
	win <= 0;
  end
end


always@(posedge clk or negedge rst)  begin
  if(!rst) begin
    game_over <= 0;
  end else if (!game_over) begin
    for (i = 0; i < 24; i = i + 1) begin
	   if(frog_x >= car_position_x[i] && frog_x < car_position_x[i] + 40 && frog_y >= car_position_y[i] && frog_y < car_position_y[i] + 20) begin
		  game_over <= 1;
		end
   end
end
end

	
always @(posedge clk or negedge rst)
begin	
	if (rst == 1'b0)
	begin
		the_vga_draw_frame_write_mem_address <= 15'd0;
		the_vga_draw_frame_write_mem_data <= 24'd0;
		the_vga_draw_frame_write_a_pixel <= 1'b0;
		current_y <= 10'd0;
		current_x <= 10'd0;
      
		
	end
	else
	begin
			
		if (active_pixels)
    begin
        the_vga_draw_frame_write_mem_address <= ((y) + (x));
        the_vga_draw_frame_write_a_pixel <= 1'b0;
        //current_y = (the_vga_draw_frame_write_mem_address / VIRTUAL_PIXEL_WIDTH);
        //current_x = (the_vga_draw_frame_write_mem_address % VIRTUAL_PIXEL_WIDTH);
		  if(game_over == 1) begin
		    if ((y >= 60 && y <= 150) && (x >= 185 && x <= 275)) begin
				the_vga_draw_frame_write_mem_data <= WHITE;
				the_vga_draw_frame_write_a_pixel <= 1'b1;
			 end else if ((y >= 60 && y <= 150) && (x >= 365 && x <= 455)) begin
				the_vga_draw_frame_write_mem_data <= WHITE;
				the_vga_draw_frame_write_a_pixel <= 1'b1;
			 end else if ((y >= 320 && y <= 410) && (x >= 95 && x <= 185)) begin
				the_vga_draw_frame_write_mem_data <= WHITE;
				the_vga_draw_frame_write_a_pixel <= 1'b1;
			 end else if ((y >= 230 && y <= 320) && (x >= 185 && x <= 455)) begin
				the_vga_draw_frame_write_mem_data <= WHITE;
				the_vga_draw_frame_write_a_pixel <= 1'b1;
			 end else if ((y >= 320 && y <= 410) && (x >= 455 && x <= 545)) begin
				the_vga_draw_frame_write_mem_data <= WHITE;
				the_vga_draw_frame_write_a_pixel <= 1'b1;
			 end else begin
				the_vga_draw_frame_write_mem_data <= RED_CAR;
				the_vga_draw_frame_write_a_pixel <= 1'b1;
			 end 
		  end else begin
		 
        if(frog_y <= 30)
		  begin
			if ((y >= 60 && y <= 150) && (x >= 185 && x <= 275)) begin
				the_vga_draw_frame_write_mem_data <= WHITE;
				the_vga_draw_frame_write_a_pixel <= 1'b1;
			 end else if ((y >= 60 && y <= 150) && (x >= 365 && x <= 455)) begin
				the_vga_draw_frame_write_mem_data <= WHITE;
				the_vga_draw_frame_write_a_pixel <= 1'b1;
			 end else if ((y >= 230 && y <= 320) && (x >= 95 && x <= 185)) begin
				the_vga_draw_frame_write_mem_data <= WHITE;
				the_vga_draw_frame_write_a_pixel <= 1'b1;
			 end else if ((y >= 320 && y <= 410) && (x >= 185 && x <= 455)) begin
				the_vga_draw_frame_write_mem_data <= WHITE;
				the_vga_draw_frame_write_a_pixel <= 1'b1;
			 end else if ((y >= 230 && y <= 320) && (x >= 455 && x <= 545)) begin
				the_vga_draw_frame_write_mem_data <= WHITE;
				the_vga_draw_frame_write_a_pixel <= 1'b1;
			 end else begin
				the_vga_draw_frame_write_mem_data <= GREEN;
				the_vga_draw_frame_write_a_pixel <= 1'b1;
			 end 
		  end else begin
		  
        if (y <= 35)
        begin
          the_vga_draw_frame_write_mem_data <= LIGHT_BLUE;
          the_vga_draw_frame_write_a_pixel <= 1'b1;
        end
        else if (y >35 && y <=79)
        begin
          the_vga_draw_frame_write_mem_data <= BLACK;
          the_vga_draw_frame_write_a_pixel <= 1'b1;
        end
      else if (y >123 && y <=167)
        begin
          the_vga_draw_frame_write_mem_data <= BLACK;
          the_vga_draw_frame_write_a_pixel <= 1'b1;
        end
      else if (y >211 && y <=255)
        begin
          the_vga_draw_frame_write_mem_data <= BLACK;
          the_vga_draw_frame_write_a_pixel <= 1'b1;
        end
      else if (y >299 && y <=343)
        begin
          the_vga_draw_frame_write_mem_data <= BLACK;
          the_vga_draw_frame_write_a_pixel <= 1'b1;
        end
      else if (y >387 && y <=431)
        begin
          the_vga_draw_frame_write_mem_data <= BLACK;
          the_vga_draw_frame_write_a_pixel <= 1'b1;
        end
        else
        begin
          the_vga_draw_frame_write_mem_data <= LIGHT_GRAY;
          the_vga_draw_frame_write_a_pixel <= 1'b1;
        end
		  end
		  //First road 
		  if(win == 0) begin
		  if (y >= car_position_y[0] && y < car_position_y[0] + 20 && x >= car_position_x[0] && x < car_position_x[0] + 40) begin
		    the_vga_draw_frame_write_mem_data <= PINK_CAR;
			 the_vga_draw_frame_write_a_pixel <= 1'b1;
		  end
		  if (y >= car_position_y[1] && y < car_position_y[1] + 20 && x >= car_position_x[1] && x < car_position_x[1] + 40) begin
		    the_vga_draw_frame_write_mem_data <= YELLOW_CAR;
			 the_vga_draw_frame_write_a_pixel <= 1'b1;
		  end
		  if (y >= car_position_y[2] && y < car_position_y[2] + 20 && x >= car_position_x[2] && x < car_position_x[2] + 40) begin
		    the_vga_draw_frame_write_mem_data <= BLUE_CAR;
			 the_vga_draw_frame_write_a_pixel <= 1'b1;
		  end
		  if (y >= car_position_y[3] && y < car_position_y[3] + 20 && x >= car_position_x[3] && x < car_position_x[3] + 40) begin
		    the_vga_draw_frame_write_mem_data <= PURPLE_CAR;
			 the_vga_draw_frame_write_a_pixel <= 1'b1;
        end

		  //Second road 
		  
        if (y >= car_position_y[4] && y < car_position_y[4] + 20 && x >= car_position_x[4] && x < car_position_x[4] + 40) begin
          the_vga_draw_frame_write_mem_data <= RED_CAR;
          the_vga_draw_frame_write_a_pixel <= 1'b1;
        end
        if (y >= car_position_y[5] && y < car_position_y[5] + 20 && x >= car_position_x[5] && x < car_position_x[5] + 40) begin
          the_vga_draw_frame_write_mem_data <= BLUE_CAR;
          the_vga_draw_frame_write_a_pixel <= 1'b1;
        end
        if (y >= car_position_y[6] && y < car_position_y[6] + 20 && x >= car_position_x[6] && x < car_position_x[6] + 40) begin
          the_vga_draw_frame_write_mem_data <= ORANGE_CAR;
          the_vga_draw_frame_write_a_pixel <= 1'b1;
        end
        if (y >= car_position_y[7] && y < car_position_y[7] + 20 && x >= car_position_x[7] && x < car_position_x[7] + 40) begin
          the_vga_draw_frame_write_mem_data <= PINK_CAR;
          the_vga_draw_frame_write_a_pixel <= 1'b1;
        end		  
		  
		  
		  //Third road 
        if (y >= car_position_y[8] && y < car_position_y[8] + 20 && x >= car_position_x[8] && x < car_position_x[8] + 40) begin
          the_vga_draw_frame_write_mem_data <= ORANGE_CAR;
          the_vga_draw_frame_write_a_pixel <= 1'b1;
        end
        if (y >= car_position_y[9] && y < car_position_y[9] + 20 && x >= car_position_x[9] && x < car_position_x[9] + 40) begin
          the_vga_draw_frame_write_mem_data <= PINK_CAR;
          the_vga_draw_frame_write_a_pixel <= 1'b1;
        end
        if (y >= car_position_y[10] && y < car_position_y[10] + 20 && x >= car_position_x[10] && x < car_position_x[10] + 40) begin
          the_vga_draw_frame_write_mem_data <= YELLOW_CAR;
          the_vga_draw_frame_write_a_pixel <= 1'b1;
        end
        if (y >= car_position_y[11] && y < car_position_y[11] + 20 && x >= car_position_x[11] && x < car_position_x[11] + 40) begin
          the_vga_draw_frame_write_mem_data <= PURPLE_CAR;
          the_vga_draw_frame_write_a_pixel <= 1'b1;
        end	
        if (y >= car_position_y[12] && y < car_position_y[12] + 20 && x >= car_position_x[12] && x < car_position_x[12] + 40) begin
          the_vga_draw_frame_write_mem_data <= RED_CAR;
          the_vga_draw_frame_write_a_pixel <= 1'b1;
        end	

		//Fourth road 
        if (y >= car_position_y[13] && y < car_position_y[13] + 20 && x >= car_position_x[13] && x < car_position_x[13] + 40) begin
          the_vga_draw_frame_write_mem_data <= PURPLE_CAR;
          the_vga_draw_frame_write_a_pixel <= 1'b1;
        end
        if (y >= car_position_y[14] && y < car_position_y[14] + 20 && x >= car_position_x[14] && x < car_position_x[14] + 40) begin
          the_vga_draw_frame_write_mem_data <= BLUE_CAR;
          the_vga_draw_frame_write_a_pixel <= 1'b1;
        end
        if (y >= car_position_y[15] && y < car_position_y[15] + 20 && x >= car_position_x[15] && x < car_position_x[15] + 40) begin
          the_vga_draw_frame_write_mem_data <= ORANGE_CAR;
          the_vga_draw_frame_write_a_pixel <= 1'b1;
        end
        if (y >= car_position_y[16] && y < car_position_y[16] + 20 && x >= car_position_x[16] && x < car_position_x[16] + 40) begin
          the_vga_draw_frame_write_mem_data <= PINK_CAR;
          the_vga_draw_frame_write_a_pixel <= 1'b1;
        end	
        if (y >= car_position_y[17] && y < car_position_y[17] + 20 && x >= car_position_x[17] && x < car_position_x[17] + 40) begin
          the_vga_draw_frame_write_mem_data <= YELLOW_CAR;
          the_vga_draw_frame_write_a_pixel <= 1'b1;
        end
		  
		  //Fifth road 
        if (y >= car_position_y[18] && y < car_position_y[18] + 20 && x >= car_position_x[18] && x < car_position_x[18] + 40) begin
          the_vga_draw_frame_write_mem_data <= PINK_CAR;
          the_vga_draw_frame_write_a_pixel <= 1'b1;
        end
        if (y >= car_position_y[19] && y < car_position_y[19] + 20 && x >= car_position_x[19] && x < car_position_x[19] + 40) begin
          the_vga_draw_frame_write_mem_data <= RED_CAR;
          the_vga_draw_frame_write_a_pixel <= 1'b1;
        end
        if (y >= car_position_y[20] && y < car_position_y[20] + 20 && x >= car_position_x[20] && x < car_position_x[20] + 40) begin
          the_vga_draw_frame_write_mem_data <= ORANGE_CAR;
          the_vga_draw_frame_write_a_pixel <= 1'b1;
        end
        if (y >= car_position_y[21] && y < car_position_y[21] + 20 && x >= car_position_x[21] && x < car_position_x[21] + 40) begin
          the_vga_draw_frame_write_mem_data <= YELLOW_CAR;
          the_vga_draw_frame_write_a_pixel <= 1'b1;
        end	
        if (y >= car_position_y[22] && y < car_position_y[22] + 20 && x >= car_position_x[22] && x < car_position_x[22] + 40) begin
          the_vga_draw_frame_write_mem_data <= BLUE_CAR;
          the_vga_draw_frame_write_a_pixel <= 1'b1;
        end
		  if (y >= car_position_y[23] && y < car_position_y[23] + 20 && x >= car_position_x[23] && x < car_position_x[23] + 40) begin
          the_vga_draw_frame_write_mem_data <= PURPLE_CAR;
          the_vga_draw_frame_write_a_pixel <= 1'b1;
        end
		  
		  //Frog display pixel drawing.
		  if (x >= frog_x && x < frog_x + 15 && y >= frog_y && y < frog_y + 15) begin
		    the_vga_draw_frame_write_mem_data <= FROG_COLOR;
			 the_vga_draw_frame_write_a_pixel <= 1'b1;
		  end
		  end
		  end
	 end
    else
    begin
        the_vga_draw_frame_write_a_pixel <= 1'b0;
    end
end
end
endmodule