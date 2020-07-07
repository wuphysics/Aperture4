/*
 * Copyright (c) 2020 Alex Chen.
 * This file is part of Aperture (https://github.com/fizban007/Aperture4.git).
 *
 * Aperture is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3.
 *
 * Aperture is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#include "boundary_condition.h"
#include "framework/config.h"
#include "utils/kernel_helper.hpp"

namespace Aperture {

template <typename Conf>
void
boundary_condition<Conf>::init() {
  m_env.get_data("Edelta", &E);
  m_env.get_data("E0", &E0);
  m_env.get_data("Bdelta", &B);
  m_env.get_data("B0", &B0);

  m_env.params().get_value("omega", m_omega_0);
  m_env.params().get_value("omega_t", m_omega_t);
}

template <typename Conf>
void
boundary_condition<Conf>::update(double dt, uint32_t step) {
  auto ext = m_grid.extent();
  typedef typename Conf::idx_t idx_t;
  typedef typename Conf::value_t value_t;

  value_t time = m_env.get_time();
  value_t omega;
  // if (m_omega_t * time < 5000.0)
  if (time < 3.0)
    omega = m_omega_0 * sin(2.0 * M_PI * m_omega_t * time);
  else
    omega = 0.0;
  Logger::print_debug("time is {}, Omega is {}", time, omega);

  kernel_launch([ext, time, omega] __device__ (auto e, auto b, auto e0, auto b0) {
      auto& grid = dev_grid<Conf::dim>();
      for (auto n1 : grid_stride_range(0, grid.dims[1])) {
        value_t theta = grid.template pos<1>(n1, false);
        value_t theta_s = grid.template pos<1>(n1, true);

        // For quantities that are not continuous across the surface
        for (int n0 = 0; n0 < grid.skirt[0] + 1; n0++) {
          auto idx = idx_t(index_t<2>(n0, n1), ext);
          e[0][idx] = e0[0][idx];
          b[1][idx] = b0[1][idx];
          // b[1][idx] = 0.0;
          b[2][idx] = b0[2][idx];
        }
        // For quantities that are continuous across the surface
        for (int n0 = 0; n0 < grid.skirt[0] + 2; n0++) {
          auto idx = idx_t(index_t<2>(n0, n1), ext);
          // value_t r = exp(grid.template pos<0>(n0, false));
          // value_t rs = exp(grid.template pos<0>(n0, true));
          value_t r = grid.template pos<0>(n0, false);
          value_t rs = grid.template pos<0>(n0, true);
          // b[0][idx] = b0[0][idx];
          b[0][idx] = 0.0;
          e[1][idx] = e0[1][idx] - omega * sin(theta_s) * r * b0[0][idx];
          // e[2][idx] = e0[2][idx] + omega * cos(theta) * rs * b0[1][idx];
          e[2][idx] = 0.0;
        }
      }
    }, E->get_ptrs(), B->get_ptrs(), E0->get_ptrs(), B0->get_ptrs());
  CudaSafeCall(cudaDeviceSynchronize());
}


template class boundary_condition<Config<2>>;

}
