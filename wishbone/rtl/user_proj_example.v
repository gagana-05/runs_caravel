// SPDX-FileCopyrightText: 2020 Efabless Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

`default_nettype none
/*
 *-------------------------------------------------------------
 *
 * user_proj_example
 *
 * This is an example of a (trivially simple) user project,
 * showing how the user project can connect to the logic
 * analyzer, the wishbone bus, and the I/O pads.
 *
 * This project generates an integer count, which is output
 * on the user area GPIO pads (digital output only).  The
 * wishbone connection allows the project to be controlled
 * (start and stop) from the management SoC program.
 *
 * See the testbenches in directory "mprj_counter" for the
 * example programs that drive this user project.  The three
 * testbenches are "io_ports", "la_test1", and "la_test2".
 *
 *-------------------------------------------------------------
 */

module user_proj_example #(
    parameter BITS = 16
)(
`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
`endif

    // Wishbone Slave ports (WB MI A)
    input wb_clk_i,
    input wb_rst_i,
    input wbs_stb_i,
    input wbs_cyc_i,
    input wbs_we_i,
    input [3:0] wbs_sel_i,
    input [31:0] wbs_dat_i,
    input [31:0] wbs_adr_i,
    output wbs_ack_o,
    output [31:0] wbs_dat_o,

    // Logic Analyzer Signals
    input  [1:0] la_data_in,
    input  [1:0] la_oenb,

    // IOs
    input  [2:0] io_in,
    output [7:0] io_out,
    output [7:0] io_oeb
);
    wire clk;
    wire rst;
    wire o_wb_stall;

    // User project signals
    assign clk = (~la_oenb[0]) ? la_data_in[0]: wb_clk_i;
    assign rst = (~la_oenb[1]) ? la_data_in[1]: wb_rst_i;

    assign io_oeb = 8'b0;

    // wb_buttons instance

    wb_buttons_leds #(
        .BASE_ADDRESS(32'h3000_0000)
    ) wb_buttons_leds_inst (
        .clk(clk),
        .reset(rst),
        .i_wb_cyc(wbs_cyc_i),
        .i_wb_stb(wbs_stb_i),
        .i_wb_we(wbs_we_i),
        .i_wb_addr(wbs_adr_i),
        .i_wb_data(wbs_dat_i),
        .o_wb_ack(wbs_ack_o),
        .o_wb_stall(),
        .o_wb_data(wbs_dat_o),
        .buttons(io_in),
        .leds(io_out)
    );

endmodule




module wb_buttons_leds #(
    parameter   [31:0]  BASE_ADDRESS    = 32'h3000_0000,        // base address
    parameter   [31:0]  LED_ADDRESS     = BASE_ADDRESS,
    parameter   [31:0]  BUTTON_ADDRESS  = BASE_ADDRESS + 4
    ) (
    input wire          clk,
    input wire          reset,

    // wb interface
    input wire          i_wb_cyc,       // wishbone transaction
    input wire          i_wb_stb,       // strobe - data valid and accepted as long as !o_wb_stall
    input wire          i_wb_we,        // write enable
    input wire  [31:0]  i_wb_addr,      // address
    input wire  [31:0]  i_wb_data,      // incoming data
    output reg          o_wb_ack,       // request is completed 
    output wire         o_wb_stall,     // cannot accept req
    output reg  [31:0]  o_wb_data,      // output data

    // buttons
    input wire  [2:0]   buttons,
    output reg  [7:0]   leds

    );

	
    assign o_wb_stall = 1'b0;

    initial leds = 8'b0;

    // writes
    always @(posedge clk) begin
        if(reset)
            leds <= 8'b0;
        else if(i_wb_stb && i_wb_cyc && i_wb_we && !o_wb_stall && i_wb_addr == LED_ADDRESS) begin
            leds <= i_wb_data[7:0];
        end
    end

    // reads
    always @(posedge clk) begin
        if(reset)
            o_wb_data <= 0;
        else if(i_wb_stb && i_wb_cyc && !i_wb_we && !o_wb_stall)
            case(i_wb_addr)
                LED_ADDRESS: 
                    o_wb_data <= {24'b0, leds};
                BUTTON_ADDRESS: 
                    o_wb_data <= {29'b0, buttons};
                default:
                    o_wb_data <= 32'b0;
            endcase
    end

    // acks
    always @(posedge clk) begin
        if(reset)
            o_wb_ack <= 0;
        else
            // return ack immediately
            o_wb_ack <= (i_wb_stb && !o_wb_stall && (i_wb_addr == LED_ADDRESS || i_wb_addr == BUTTON_ADDRESS));
    end

endmodule

`default_nettype wire

