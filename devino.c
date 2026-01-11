/*
lx symbolic link expansion
Copyright (C) 2026 Kim Saunders

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

#include "devino.h"

int devinocmp(const void *a, const void *b) {
  const struct devino *devino_a = a, *devino_b = b;
  int difference = devino_a->st_dev - devino_b->st_dev;
  if (difference) return difference;
  return devino_a->st_ino - devino_b->st_ino;
}
