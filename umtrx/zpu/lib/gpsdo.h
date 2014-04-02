/*
 * Copyright 2012 Sylvain Munaut <tnt@246tNt.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef INCLUDED_GPSDO_H
#define INCLUDED_GPSDO_H


void gpsdo_init(void);

/* Set value of the VCTCXO DAC */
int set_vctcxo_dac(uint16_t v);

/* Get the current VCTCXO DAC value */
uint16_t get_vctcxo_dac(void);

#endif /* INCLUDED_GPSDO_H */
