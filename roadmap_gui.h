/* roadmap_gui.h - general definitions used by the RoadMap GUI module.
 *
 * LICENSE:
 *
 *   Copyright 2002 Pascal F. Martin
 *
 *   This file is part of RoadMap.
 *
 *   RoadMap is free software; you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation; either version 2 of the License, or
 *   (at your option) any later version.
 *
 *   RoadMap is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details.
 *
 *   You should have received a copy of the GNU General Public License
 *   along with RoadMap; if not, write to the Free Software
 *   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#ifndef _ROADMAP_GUI__H_
#define _ROADMAP_GUI__H_

#include "roadmap_types.h"


typedef struct {

   int x;
   int y;

} RoadMapGuiPoint;

typedef struct {
   
   float x;
   float y;
   
} RoadMapGuiPointF;

typedef struct {

   int minx;
   int miny;
   int maxx;
   int maxy;

} RoadMapGuiRect;

#endif /* _ROADMAP_GUI__H_ */

