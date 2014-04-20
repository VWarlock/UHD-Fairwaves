//
// Copyright 2010-2011 Ettus Research LLC
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#ifndef INCLUDED_USRP1_IFACE_HPP
#define INCLUDED_USRP1_IFACE_HPP

#include "fx2_ctrl.hpp"
#include "wb_iface.hpp"
#include <uhd/types/serial.hpp>
#include <boost/shared_ptr.hpp>
#include <boost/utility.hpp>

/*!
 * The usrp1 interface class:
 * Provides a set of functions to implementation layer.
 * Including spi, peek, poke, control...
 */
class usrp1_iface : public wb_iface, public uhd::i2c_iface, public uhd::spi_iface, boost::noncopyable{
public:
    typedef boost::shared_ptr<usrp1_iface> sptr;

    /*!
     * Make a new usrp1 interface with the control transport.
     * \param ctrl_transport the usrp controller object
     * \return a new usrp1 interface object
     */
    static sptr make(uhd::usrp::fx2_ctrl::sptr ctrl_transport);
};

#endif /* INCLUDED_USRP1_IFACE_HPP */