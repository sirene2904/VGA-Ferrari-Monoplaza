/*
 * Copyright (c) 2024 Tiny Tapeout LTD
 * SPDX-License-Identifier: Apache-2.0
 * Author: Uri Shaked
 *
 * Imagen 320x240 (2 bpp, img2rom) rebotando, con colores de la paleta.
 * Movimiento invertido (espejo en ambos ejes).
 * Experimental: no cabe en una tile, solo para simular en VGA Playground.
 */

`default_nettype none

// verilator lint_off WIDTH

parameter DISPLAY_WIDTH  = 640;  // Ancho de pantalla VGA
parameter DISPLAY_HEIGHT = 480;  // Alto de pantalla VGA

module tt_um_SIRENE2904_FERRARIMONOPLAZA (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  localparam LOGO_WIDTH  = 320;  // Ancho de la imagen
  localparam LOGO_HEIGHT = 240;  // Alto de la imagen

  // VGA signals
  wire hsync;
  wire vsync;
  reg [1:0] R;
  reg [1:0] G;
  reg [1:0] B;
  wire video_active;
  wire [9:0] pix_x;
  wire [9:0] pix_y;

  // TinyVGA PMOD
  assign uo_out  = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

  assign uio_out = 0;
  assign uio_oe  = 0;

  wire _unused_ok = &{ena, ui_in, uio_in};

  reg [9:0] prev_y;

  hvsync_generator vga_sync_gen (
      .clk(clk),
      .reset(~rst_n),
      .hsync(hsync),
      .vsync(vsync),
      .display_on(video_active),
      .hpos(pix_x),
      .vpos(pix_y)
  );

  // Posicion y direccion del rebote
  reg [9:0] logo_left;
  reg [9:0] logo_top;
  reg dir_x;
  reg dir_y;

  wire [9:0] x = pix_x - logo_left;
  wire [9:0] y = pix_y - logo_top;
  wire in_display = (pix_x < DISPLAY_WIDTH) && (pix_y < DISPLAY_HEIGHT);
  wire logo_area  = (x < LOGO_WIDTH) && (y < LOGO_HEIGHT);

  wire [1:0] pixel_index;
  wire [5:0] color;

  bitmap_rom rom1 (
      .x(x),
      .y(y),
      .pixel(pixel_index)
  );

  palette palette_inst (
      .color_index(pixel_index),
      .rrggbb(color)
  );

  // Salida RGB
  always @(posedge clk) begin
    if (~rst_n) begin
      R <= 0;
      G <= 0;
      B <= 0;
    end else begin
      R <= 0;
      G <= 0;
      B <= 0;
      if (video_active && in_display && logo_area) begin
        R <= color[5:4];
        G <= color[3:2];
        B <= color[1:0];
      end
    end
  end

  // Logica de rebote
  always @(posedge clk) begin
    if (~rst_n) begin
      logo_left <= (DISPLAY_WIDTH - LOGO_WIDTH) / 2;
      logo_top  <= (DISPLAY_HEIGHT - LOGO_HEIGHT) / 2;
      dir_x <= 0;  // espejo: empieza yendo a la izquierda (antes derecha)
      dir_y <= 1;  // espejo: empieza yendo hacia abajo (antes arriba)
    end else begin
      prev_y <= pix_y;
      if (pix_y == 0 && prev_y != pix_y) begin
        logo_left <= logo_left + (dir_x ? 1 : -1);
        logo_top  <= logo_top + (dir_y ? 1 : -1);
        if (logo_left - 1 == 0 && !dir_x) begin
          dir_x <= 1;
        end
        if (logo_left + 1 == DISPLAY_WIDTH - LOGO_WIDTH && dir_x) begin
          dir_x <= 0;
        end
        if (logo_top - 1 == 0 && !dir_y) begin
          dir_y <= 1;
        end
        if (logo_top + 1 == DISPLAY_HEIGHT - LOGO_HEIGHT && dir_y) begin
          dir_y <= 0;
        end
      end
    end
  end

endmodule
