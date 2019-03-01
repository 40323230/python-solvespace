# -*- coding: utf-8 -*-
# cython: language_level=3, embedsignature=True

"""Wrapper source code of Solvespace.

author: Yuan Chang
copyright: Copyright (C) 2016-2019
license: AGPL
email: pyslvs@gmail.com
"""

cimport cython
from cpython.mem cimport PyMem_Malloc, PyMem_Free
from cpython.object cimport Py_EQ, Py_NE
from libcpp.vector cimport vector


cpdef tuple quaternion_u(double qw, double qx, double qy, double qz):
    cdef double x, y, z
    Slvs_QuaternionV(qw, qx, qy, qz, &x, &y, &z)
    return x, y, z


cpdef tuple quaternion_v(double qw, double qx, double qy, double qz):
    cdef double x, y, z
    Slvs_QuaternionV(qw, qx, qy, qz, &x, &y, &z)
    return x, y, z


cpdef tuple quaternion_n(double qw, double qx, double qy, double qz):
    cdef double x, y, z
    Slvs_QuaternionN(qw, qx, qy, qz, &x, &y, &z)
    return x, y, z


cpdef tuple make_quaternion(double ux, double uy, double uz, double vx, double vy, double vz):
    cdef double qw, qx, qy, qz
    Slvs_MakeQuaternion(ux, uy, uz, vx, vy, vz, &qw, &qx, &qy, &qz)
    return qw, qx, qy, qz


cdef class Params:

    """Python object to handle multiple parameter handles."""

    cdef vector[Slvs_hParam] param_list

    @staticmethod
    cdef Params create(Slvs_hParam *p, size_t count):
        """Constructor."""
        cdef Params params = Params.__new__(Params)
        cdef size_t i
        with nogil:
            for i in range(count):
                params.param_list.push_back(p[i])
        return params

    def __repr__(self) -> str:
        cdef str m = f"{self.__class__.__name__}(["
        cdef size_t i
        cdef size_t s = self.param_list.size()
        for i in range(s):
            m += str(<int>self.param_list[i])
            if i != s - 1:
                m += ", "
        m += "])"
        return m

# A virtual work plane that present 3D entity or constraint.
cdef Entity _WP_FREE_IN_3D = Entity.__new__(Entity)
_WP_FREE_IN_3D.t = SLVS_E_WORKPLANE
_WP_FREE_IN_3D.h = SLVS_FREE_IN_3D
_WP_FREE_IN_3D.g = 0
_WP_FREE_IN_3D.params = Params.create(NULL, 0)

# A "None" entity used to fill in constraint option.
cdef Entity _ENTITY_NONE = Entity.__new__(Entity)
_ENTITY_NONE.t = 0
_ENTITY_NONE.h = 0
_ENTITY_NONE.g = 0
_ENTITY_NONE.params = Params.create(NULL, 0)

# Entity names
cdef dict _NAME_OF_ENTITIES = {
    SLVS_E_POINT_IN_3D: "point 3d",
    SLVS_E_POINT_IN_2D: "point 2d",
    SLVS_E_NORMAL_IN_2D: "normal 2d",
    SLVS_E_NORMAL_IN_3D: "normal 3d",
    SLVS_E_DISTANCE: "distance",
    SLVS_E_WORKPLANE: "work plane",
    SLVS_E_LINE_SEGMENT: "line segment",
    SLVS_E_CUBIC: "cubic",
    SLVS_E_CIRCLE: "circle",
    SLVS_E_ARC_OF_CIRCLE: "arc",
}


cdef class Entity:

    """Python object to handle a pointer of 'Slvs_hEntity'."""

    cdef int t
    cdef Slvs_hEntity h, wp
    cdef Slvs_hGroup g
    cdef readonly Params params

    FREE_IN_3D = _WP_FREE_IN_3D
    NONE = _ENTITY_NONE

    @staticmethod
    cdef Entity create(Slvs_Entity *e, size_t p_size):
        """Constructor."""
        cdef Entity entity = Entity.__new__(Entity)
        with nogil:
            entity.t = e.type
            entity.h = e.h
            entity.wp = e.wrkpl
            entity.g = e.group
        entity.params = Params.create(e.param, p_size)
        return entity

    def __richcmp__(self, other: Entity, op: cython.int) -> bint:
        """Compare the entities."""
        if op == Py_EQ:
            return (
                self.t == other.t and
                self.h == other.h and
                self.wp == other.wp and
                self.g == other.g and
                self.params == other.params
            )
        elif op == Py_NE:
            return (
                self.t != other.t or
                self.h != other.h or
                self.wp != other.wp or
                self.g != other.g or
                self.params != other.params
            )
        else:
            raise TypeError(
                f"'{op}' not support between instances of "
                f"{type(self)} and {type(other)}"
            )

    cpdef bint is_3d(self):
        return self.wp == SLVS_FREE_IN_3D

    cpdef bint is_none(self):
        return self.h == 0

    cpdef bint is_point_2d(self):
        return self.t == SLVS_E_POINT_IN_2D

    cpdef bint is_point_3d(self):
        return self.t == SLVS_E_POINT_IN_3D

    cpdef bint is_point(self):
        return self.is_point_2d() or self.is_point_3d()

    cpdef bint is_normal_2d(self):
        return self.t == SLVS_E_NORMAL_IN_2D

    cpdef bint is_normal_3d(self):
        return self.t == SLVS_E_NORMAL_IN_3D

    cpdef bint is_normal(self):
        return self.is_normal_2d() or self.is_normal_3d()

    cpdef bint is_distance(self):
        return self.t == SLVS_E_DISTANCE

    cpdef bint is_work_plane(self):
        return self.t == SLVS_E_WORKPLANE

    cpdef bint is_line_2d(self):
        return self.is_line() and not self.is_3d()

    cpdef bint is_line_3d(self):
        return self.is_line() and self.is_3d()

    cpdef bint is_line(self):
        return self.t == SLVS_E_LINE_SEGMENT

    cpdef bint is_cubic(self):
        return self.t == SLVS_E_CUBIC

    cpdef bint is_circle(self):
        return self.t == SLVS_E_CIRCLE

    cpdef bint is_arc(self):
        return self.t == SLVS_E_ARC_OF_CIRCLE

    def __repr__(self) -> str:
        cdef int h = <int>self.h
        cdef int g = <int>self.g
        cdef str t = _NAME_OF_ENTITIES[<int>self.t]
        return (
            f"{self.__class__.__name__}"
            f"(handle={h}, group={g}, type=<{t}>, is_3d={self.is_3d()}, params={self.params})"
        )


cdef class SolverSystem:

    """Python object of 'Slvs_System'."""

    cdef Slvs_hGroup g
    cdef Slvs_System sys
    cdef vector[Slvs_Param] param_list
    cdef vector[Slvs_Entity] entity_list
    cdef vector[Slvs_Constraint] cons_list
    cdef vector[Slvs_hConstraint] failed_list

    def __cinit__(self):
        self.g = 0
        self.sys.params = self.sys.entities = self.sys.constraints = 0

    cdef inline void copy_to_sys(self) nogil:
        """Copy data from stack into system."""
        # Copy
        cdef int i = 0
        cdef Slvs_Param param
        for param in self.param_list:
            self.sys.param[i] = param
            i += 1

        i = 0
        cdef Slvs_Entity entity
        for entity in self.entity_list:
            self.sys.entity[i] = entity
            i += 1

        i = 0
        cdef Slvs_Constraint con
        for con in self.cons_list:
            self.sys.constraint[i] = con
            i += 1

    cpdef void clear(self):
        self.param_list.clear()
        self.entity_list.clear()
        self.cons_list.clear()
        self.free()

    cdef inline void failed_collecting(self) nogil:
        """Collecting the failed constraints."""
        self.failed_list.clear()
        cdef int i
        for i in range(self.sys.faileds):
            self.failed_list.push_back(self.sys.failed[i])

    cdef inline void free(self):
        PyMem_Free(self.sys.param)
        PyMem_Free(self.sys.entity)
        PyMem_Free(self.sys.constraint)
        PyMem_Free(self.sys.failed)

    cpdef void set_group(self, size_t g):
        """Set the current group by integer."""
        self.g = <Slvs_hGroup>g

    cpdef int group(self):
        """Return the current group by integer."""
        return <int>self.g

    cpdef list params(self, Params p):
        """Get the parameters by Params object."""
        cdef list param_list = []
        cdef size_t i
        for i in range(p.param_list.size()):
            param_list.append(self.param_list[<size_t>p.param_list[i]].val)
        return tuple(param_list)

    cpdef int dof(self):
        """Return the DOF of system."""
        return self.sys.dof

    cpdef list faileds(self):
        """Return the count of failed constraint."""
        failed_list = []
        cdef Slvs_hConstraint error
        for error in self.failed_list:
            failed_list.append(<int>error)
        return failed_list

    cpdef int solve(self):
        """Solve the system."""
        # Parameters
        self.sys.param = <Slvs_Param *>PyMem_Malloc(self.param_list.size() * sizeof(Slvs_Param))

        # Entities
        self.sys.entity = <Slvs_Entity *>PyMem_Malloc(self.entity_list.size() * sizeof(Slvs_Entity))

        # Constraints
        cdef size_t cons_size = self.cons_list.size()
        self.sys.constraint = <Slvs_Constraint *>PyMem_Malloc(cons_size * sizeof(Slvs_Constraint))
        self.sys.failed = <Slvs_hConstraint *>PyMem_Malloc(cons_size * sizeof(Slvs_hConstraint))
        self.sys.faileds = cons_size

        # Copy to system
        self.copy_to_sys()
        # Solve
        Slvs_Solve(&self.sys, self.g)
        # Failed constraints and free memory.
        self.failed_collecting()
        self.free()
        return self.sys.result

    cpdef Entity create_2d_base(self):
        """Create a basic 2D system and return the work plane."""
        cdef double qw, qx, qy, qz
        qw, qx, qy, qz = make_quaternion(1, 0, 0, 0, 1, 0)
        cdef Entity origin = self.add_point_3d(0, 0, 0)
        cdef Entity nm = self.add_normal_3d(qw, qx, qy, qz)
        return self.add_work_plane(origin, nm)

    cdef inline Slvs_hParam new_param(self, double val) nogil:
        """Add a parameter."""
        self.sys.params += 1
        cdef Slvs_hParam h = <Slvs_hParam>self.sys.params
        self.param_list.push_back(Slvs_MakeParam(h, self.g, val))
        return h

    cdef inline Slvs_hEntity eh(self) nogil:
        """Return new entity handle."""
        self.sys.entities += 1
        return <Slvs_hEntity>self.sys.entities

    cpdef Entity add_point_2d(self, double u, double v, Entity wp):
        """Add 2D point."""
        if wp is None or not wp.is_work_plane():
            raise TypeError(f"{wp} is not a work plane")

        cdef Slvs_hParam u_p = self.new_param(u)
        cdef Slvs_hParam v_p = self.new_param(v)
        cdef Slvs_Entity e = Slvs_MakePoint2d(self.eh(), self.g, wp.h, u_p, v_p)
        self.entity_list.push_back(e)

        return Entity.create(&e, 2)

    cpdef Entity add_point_3d(self, double x, double y, double z):
        """Add 3D point."""
        cdef Slvs_hParam x_p = self.new_param(x)
        cdef Slvs_hParam y_p = self.new_param(y)
        cdef Slvs_hParam z_p = self.new_param(z)
        cdef Slvs_Entity e = Slvs_MakePoint3d(self.eh(), self.g, x_p, y_p, z_p)
        self.entity_list.push_back(e)

        return Entity.create(&e, 3)

    cpdef Entity add_normal_2d(self, Entity wp):
        """Add a 2D normal."""
        if wp is None or not wp.is_work_plane():
            raise TypeError(f"{wp} is not a work plane")

        cdef Slvs_Entity e = Slvs_MakeNormal2d(self.eh(), self.g, wp.h)
        self.entity_list.push_back(e)

        return Entity.create(&e, 0)

    cpdef Entity add_normal_3d(self, double qw, double qx, double qy, double qz):
        """Add a 3D normal."""
        cdef Slvs_hParam w_p = self.new_param(qw)
        cdef Slvs_hParam x_p = self.new_param(qx)
        cdef Slvs_hParam y_p = self.new_param(qy)
        cdef Slvs_hParam z_p = self.new_param(qz)
        cdef Slvs_Entity e = Slvs_MakeNormal3d(self.eh(), self.g, w_p, x_p, y_p, z_p)
        self.entity_list.push_back(e)

        return Entity.create(&e, 4)

    cpdef Entity add_distance(self, double d, Entity wp):
        """Add a 2D distance."""
        if wp is None or not wp.is_work_plane():
            raise TypeError(f"{wp} is not a work plane")

        cdef Slvs_hParam d_p = self.new_param(d)
        cdef Slvs_Entity e = Slvs_MakeDistance(self.eh(), self.g, wp.h, d_p)
        self.entity_list.push_back(e)

        return Entity.create(&e, 1)

    cpdef Entity add_line_2d(self, Entity p1, Entity p2, Entity wp):
        """Add a 2D line."""
        if wp is None or not wp.is_work_plane():
            raise TypeError(f"{wp} is not a work plane")
        if p1 is None or not p1.is_point_2d():
            raise TypeError(f"{p1} is not a 2d point")
        if p2 is None or not p2.is_point_2d():
            raise TypeError(f"{p2} is not a 2d point")

        cdef Slvs_Entity e = Slvs_MakeLineSegment(self.eh(), self.g, wp.h, p1.h, p2.h)
        self.entity_list.push_back(e)

        return Entity.create(&e, 0)

    cpdef Entity add_line_3d(self, Entity p1, Entity p2):
        """Add a 3D line."""
        if p1 is None or not p1.is_point_3d():
            raise TypeError(f"{p1} is not a 3d point")
        if p2 is None or not p2.is_point_3d():
            raise TypeError(f"{p2} is not a 3d point")

        cdef Slvs_Entity e = Slvs_MakeLineSegment(self.eh(), self.g, SLVS_FREE_IN_3D, p1.h, p2.h)
        self.entity_list.push_back(e)

        return Entity.create(&e, 0)

    cpdef Entity add_cubic(self, Entity p1, Entity p2, Entity p3, Entity p4, Entity wp):
        """Add a 2D cubic."""
        if wp is None or not wp.is_work_plane():
            raise TypeError(f"{wp} is not a work plane")
        if p1 is None or not p1.is_point_2d():
            raise TypeError(f"{p1} is not a 2d point")
        if p2 is None or not p2.is_point_2d():
            raise TypeError(f"{p2} is not a 2d point")
        if p3 is None or not p3.is_point_2d():
            raise TypeError(f"{p3} is not a 2d point")
        if p4 is None or not p4.is_point_2d():
            raise TypeError(f"{p4} is not a 2d point")

        cdef Slvs_Entity e = Slvs_MakeCubic(self.eh(), self.g, wp.h, p1.h, p2.h, p3.h, p4.h)
        self.entity_list.push_back(e)

        return Entity.create(&e, 0)

    cpdef Entity add_arc(self, Entity nm, Entity ct, Entity start, Entity end, Entity wp):
        """Add an 2D arc."""
        if wp is None or not wp.is_work_plane():
            raise TypeError(f"{wp} is not a work plane")
        if nm is None or not nm.is_normal_3d():
            raise TypeError(f"{nm} is not a 3d normal")
        if ct is None or not ct.is_point_2d():
            raise TypeError(f"{ct} is not a 2d point")
        if start is None or not start.is_point_2d():
            raise TypeError(f"{start} is not a 2d point")
        if end is None or not end.is_point_2d():
            raise TypeError(f"{end} is not a 2d point")

        cdef Slvs_Entity e = Slvs_MakeArcOfCircle(self.eh(), self.g, wp.h, nm.h, ct.h, start.h, end.h)
        self.entity_list.push_back(e)

        return Entity.create(&e, 0)

    cpdef Entity add_circle(self, Entity nm, Entity ct, Entity radius, Entity wp):
        """Add a 2D circle."""
        if wp is None or not wp.is_work_plane():
            raise TypeError(f"{wp} is not a work plane")
        if nm is None or not nm.is_normal_3d():
            raise TypeError(f"{nm} is not a 3d normal")
        if ct is None or not ct.is_point_2d():
            raise TypeError(f"{ct} is not a 2d point")
        if radius is None or not radius.is_distance():
            raise TypeError(f"{radius} is not a distance")

        cdef Slvs_Entity e = Slvs_MakeCircle(self.eh(), self.g, wp.h, ct.h, nm.h, radius.h)
        self.entity_list.push_back(e)

        return Entity.create(&e, 0)

    cpdef Entity add_work_plane(self, Entity origin, Entity nm):
        """Add a 3D work plane."""
        if origin is None or origin.t != SLVS_E_POINT_IN_3D:
            raise TypeError(f"{origin} is not a 3d point")
        if nm is None or nm.t != SLVS_E_NORMAL_IN_3D:
            raise TypeError(f"{nm} is not a 3d normal")

        cdef Slvs_Entity e = Slvs_MakeWorkplane(self.eh(), self.g, origin.h, nm.h)
        self.entity_list.push_back(e)

        return Entity.create(&e, 0)

    cpdef void add_constraint(
        self,
        Constraint c_type,
        Entity wp,
        double v,
        Entity p1,
        Entity p2,
        Entity e1,
        Entity e2,
        Entity e3 = _ENTITY_NONE,
        Entity e4 = _ENTITY_NONE,
        int other = 0,
        int other2 = 0
    ):
        """Add customized constraint."""
        if wp is None or not wp.is_work_plane():
            raise TypeError(f"{wp} is not a work plane")

        cdef Entity e
        for e in (p1, p2):
            if e is None or not (e.is_none() or e.is_point()):
                raise TypeError(f"{e} is not a point")
        for e in (e1, e2, e3, e4):
            if e is None:
                raise TypeError(f"{e} is not a entity")

        self.sys.constraints += 1
        cdef Slvs_Constraint c
        c.h = <Slvs_hConstraint>self.sys.constraints
        c.group = self.g
        c.type = c_type
        c.wrkpl = wp.h
        c.valA = v
        c.ptA = p1.h
        c.ptB = p2.h
        c.entityA = e1.h
        c.entityB = e2.h
        c.entityC = e3.h
        c.entityD = e4.h
        c.other = other
        c.other2 = other2
        self.cons_list.push_back(c)

    #####
    # Constraint methods.
    #####

    cpdef void coincident(self, Entity e1, Entity e2, Entity wp = _WP_FREE_IN_3D):
        """Coincident two entities."""
        if e1.is_point() and e2.is_point():
            self.add_constraint(
                POINTS_COINCIDENT,
                wp,
                0.,
                e1,
                e2,
                _ENTITY_NONE,
                _ENTITY_NONE
            )
        elif e1.is_point() and e2.is_work_plane() and wp is _WP_FREE_IN_3D:
            self.add_constraint(
                PT_IN_PLANE,
                e2,
                0.,
                e1,
                _ENTITY_NONE,
                e2,
                _ENTITY_NONE
            )
        elif e1.is_point() and (e2.is_line() or e2.is_circle()):
            self.add_constraint(
                PT_ON_LINE if e2.is_line() else PT_ON_CIRCLE,
                wp,
                0.,
                e1,
                _ENTITY_NONE,
                e2,
                _ENTITY_NONE
            )
        else:
            raise TypeError(f"unsupported entities: {e1}, {e2}, {wp}")

    cpdef void distance(
        self,
        Entity e1,
        Entity e2,
        double value,
        Entity wp = _WP_FREE_IN_3D,
    ):
        """Distance constraint between two entities."""
        if value == 0.:
            self.coincident(e1, e2, wp)
            return

        if e1.is_point() and e2.is_point():
            self.add_constraint(
                PT_PT_DISTANCE,
                wp,
                value,
                e1,
                e2,
                _ENTITY_NONE,
                _ENTITY_NONE
            )
        elif e1.is_point() and e2.is_work_plane() and wp is _WP_FREE_IN_3D:
            self.add_constraint(
                PT_PLANE_DISTANCE,
                e2,
                value,
                e1,
                _ENTITY_NONE,
                e2,
                _ENTITY_NONE
            )
        elif e1.is_point() and e2.is_line():
            self.add_constraint(
                PT_LINE_DISTANCE,
                wp,
                value,
                e1,
                _ENTITY_NONE,
                e2,
                _ENTITY_NONE
            )
        else:
            raise TypeError(f"unsupported entities: {e1}, {e2}, {wp}")

    cpdef void equal(self, Entity e1, Entity e2, Entity wp = _WP_FREE_IN_3D):
        """Equal constraint between two entities."""
        if e1.is_line() and e2.is_line():
            self.add_constraint(
                EQUAL_LENGTH_LINES,
                wp,
                0.,
                _ENTITY_NONE,
                _ENTITY_NONE,
                e1,
                e2
            )
        elif e1.is_line() and (e2.is_arc() or e2.is_circle()):
            self.add_constraint(
                EQUAL_LINE_ARC_LEN,
                wp,
                0.,
                _ENTITY_NONE,
                _ENTITY_NONE,
                e1,
                e2
            )
        elif (e1.is_arc() or e1.is_circle()) and (e2.is_arc() or e2.is_circle()):
            self.add_constraint(
                EQUAL_RADIUS,
                wp,
                0.,
                _ENTITY_NONE,
                _ENTITY_NONE,
                e1,
                e2
            )
        else:
            raise TypeError(f"unsupported entities: {e1}, {e2}, {wp}")

    cpdef void equal_included_angle(
        self,
        Entity e1,
        Entity e2,
        Entity e3,
        Entity e4,
        Entity wp
    ):
        """Constraint that line 1 and line 2, line 3 and line 4
        must have same included angle.
        """
        if wp is _WP_FREE_IN_3D:
            raise ValueError("this is a 2d constraint")

        if e1.is_line_2d() and e2.is_line_2d() and e3.is_line_2d() and e4.is_line_2d():
            self.add_constraint(
                EQUAL_ANGLE,
                wp,
                0.,
                _ENTITY_NONE,
                _ENTITY_NONE,
                e1,
                e2,
                e3,
                e4
            )
        else:
            raise TypeError(f"unsupported entities: {e1}, {e2}, {e3}, {e4}, {wp}")

    cpdef void equal_point_to_line(
        self,
        Entity e1,
        Entity e2,
        Entity e3,
        Entity e4,
        Entity wp
    ):
        """Constraint that point 1 and line 1, point 2 and line 2
        must have same distance.
        """
        if wp is _WP_FREE_IN_3D:
            raise ValueError("this is a 2d constraint")

        if e1.is_point_2d() and e2.is_line_2d() and e3.is_point_2d() and e4.is_line_2d():
            self.add_constraint(
                EQ_PT_LN_DISTANCES,
                wp,
                0.,
                e1,
                e3,
                e2,
                e4
            )
        else:
            raise TypeError(f"unsupported entities: {e1}, {e2}, {e3}, {e4}, {wp}")

    cpdef void ratio(self, Entity e1, Entity e2, double value, Entity wp):
        """The ratio constraint between two lines."""
        if wp is _WP_FREE_IN_3D:
            raise ValueError("this is a 2d constraint")

        if e1.is_line_2d() and e2.is_line_2d():
            self.add_constraint(
                EQ_PT_LN_DISTANCES,
                wp,
                value,
                _ENTITY_NONE,
                _ENTITY_NONE,
                e1,
                e2
            )
        else:
            raise TypeError(f"unsupported entities: {e1}, {e2}, {wp}")

    cpdef void symmetric(
        self,
        Entity e1,
        Entity e2,
        Entity e3 = _ENTITY_NONE,
        Entity wp = _WP_FREE_IN_3D
    ):
        """Symmetric constraint between two points."""
        if e1.is_point_3d() and e2.is_point_3d() and e3.is_work_plane() and wp is _WP_FREE_IN_3D:
            self.add_constraint(
                SYMMETRIC,
                wp,
                0.,
                e1,
                e2,
                e3,
                _ENTITY_NONE
            )
        elif e1.is_point_2d() and e2.is_point_2d() and e3.is_work_plane() and wp is _WP_FREE_IN_3D:
            self.add_constraint(
                SYMMETRIC,
                e3,
                0.,
                e1,
                e2,
                e3,
                _ENTITY_NONE
            )
        elif e1.is_point_2d() and e2.is_point_2d() and e3.is_line_2d():
            if wp is _WP_FREE_IN_3D:
                raise ValueError("this is a 2d constraint")
            self.add_constraint(
                SYMMETRIC_LINE,
                wp,
                0.,
                e1,
                e2,
                e3,
                _ENTITY_NONE
            )
        else:
            raise TypeError(f"unsupported entities: {e1}, {e2}, {e3}, {wp}")

    cpdef void symmetric_h(self, Entity e1, Entity e2, Entity wp):
        """Symmetric constraint between two points with horizontal line."""
        if wp is _WP_FREE_IN_3D:
            raise ValueError("this is a 2d constraint")

        if e1.is_point_2d() and e2.is_point_2d():
            self.add_constraint(
                SYMMETRIC_HORIZ,
                wp,
                0.,
                e1,
                e2,
                _ENTITY_NONE,
                _ENTITY_NONE
            )
        else:
            raise TypeError(f"unsupported entities: {e1}, {e2}, {wp}")

    cpdef void symmetric_v(self, Entity e1, Entity e2, Entity wp):
        """Symmetric constraint between two points with vertical line."""
        if wp is _WP_FREE_IN_3D:
            raise ValueError("this is a 2d constraint")

        if e1.is_point_2d() and e2.is_point_2d():
            self.add_constraint(
                SYMMETRIC_VERT,
                wp,
                0.,
                e1,
                e2,
                _ENTITY_NONE,
                _ENTITY_NONE
            )
        else:
            raise TypeError(f"unsupported entities: {e1}, {e2}, {wp}")

    cpdef void midpoint(
        self,
        Entity e1,
        Entity e2,
        Entity wp = _WP_FREE_IN_3D
    ):
        """Midpoint constraint between a point and a line."""
        if e1.is_point() and e2.is_line():
            self.add_constraint(
                AT_MIDPOINT,
                wp,
                0.,
                e1,
                _ENTITY_NONE,
                e2,
                _ENTITY_NONE
            )
        else:
            raise TypeError(f"unsupported entities: {e1}, {e2}, {wp}")

    cpdef void horizontal(self, Entity e1, Entity wp):
        """Horizontal constraint of a 2d point."""
        if wp is _WP_FREE_IN_3D:
            raise ValueError("this is a 2d constraint")

        if e1.is_line_2d():
            self.add_constraint(
                HORIZONTAL,
                wp,
                0.,
                e1,
                _ENTITY_NONE,
                _ENTITY_NONE,
                _ENTITY_NONE
            )
        else:
            raise TypeError(f"unsupported entities: {e1}, {wp}")

    cpdef void vertical(self, Entity e1, Entity wp):
        """Vertical constraint of a 2d point."""
        if wp is _WP_FREE_IN_3D:
            raise ValueError("this is a 2d constraint")

        if e1.is_line_2d():
            self.add_constraint(
                VERTICAL,
                wp,
                0.,
                e1,
                _ENTITY_NONE,
                _ENTITY_NONE,
                _ENTITY_NONE
            )
        else:
            raise TypeError(f"unsupported entities: {e1}, {wp}")

    cpdef void diameter(self, Entity e1, double value, Entity wp):
        """Diameter constraint of a circular entities."""
        if wp is _WP_FREE_IN_3D:
            raise ValueError("this is a 2d constraint")

        if e1.is_arc() or e1.is_circle():
            self.add_constraint(
                DIAMETER,
                wp,
                value,
                e1,
                _ENTITY_NONE,
                _ENTITY_NONE,
                _ENTITY_NONE
            )
        else:
            raise TypeError(f"unsupported entities: {e1}, {wp}")

    cpdef void same_orientation(self, Entity e1, Entity e2, double value):
        """Equal orientation constraint between two 3d normals."""
        if e1.is_normal_3d() and e2.is_normal_3d():
            self.add_constraint(
                SAME_ORIENTATION,
                _WP_FREE_IN_3D,
                value,
                _ENTITY_NONE,
                _ENTITY_NONE,
                e1,
                e2
            )
        else:
            raise TypeError(f"unsupported entities: {e1}, {e2}")

    cpdef void angle(self, Entity e1, Entity e2, double value, Entity wp):
        """Angle constraint between two 2d lines."""
        if wp is _WP_FREE_IN_3D:
            raise ValueError("this is a 2d constraint")

        if e1.is_line_2d() and e2.is_line_2d():
            self.add_constraint(
                ANGLE,
                wp,
                value,
                _ENTITY_NONE,
                _ENTITY_NONE,
                e1,
                e2
            )
        else:
            raise TypeError(f"unsupported entities: {e1}, {e2}, {wp}")

    cpdef void perpendicular(self, Entity e1, Entity e2, Entity wp):
        """Perpendicular constraint between two 2d lines."""
        if wp is _WP_FREE_IN_3D:
            raise ValueError("this is a 2d constraint")

        if e1.is_line_2d() and e2.is_line_2d():
            self.add_constraint(
                PERPENDICULAR,
                wp,
                0.,
                _ENTITY_NONE,
                _ENTITY_NONE,
                e1,
                e2
            )
        else:
            raise TypeError(f"unsupported entities: {e1}, {e2}, {wp}")

    cpdef void parallel(self, Entity e1, Entity e2, Entity wp = _WP_FREE_IN_3D):
        """Parallel constraint between two lines."""
        if e1.is_line() and e2.is_line():
            self.add_constraint(
                PARALLEL,
                wp,
                0.,
                _ENTITY_NONE,
                _ENTITY_NONE,
                e1,
                e2
            )
        else:
            raise TypeError(f"unsupported entities: {e1}, {e2}, {wp}")

    cpdef void tangent(self, Entity e1, Entity e2, Entity wp = _WP_FREE_IN_3D):
        """Parallel constraint between two entities."""
        if e1.is_arc() and e2.is_line_2d():
            if wp is _WP_FREE_IN_3D:
                raise ValueError("this is a 2d constraint")
            self.add_constraint(
                ARC_LINE_TANGENT,
                wp,
                0.,
                _ENTITY_NONE,
                _ENTITY_NONE,
                e1,
                e2
            )
        elif e1.is_cubic() and e2.is_line_3d() and wp is _WP_FREE_IN_3D:
            self.add_constraint(
                CUBIC_LINE_TANGENT,
                wp,
                0.,
                _ENTITY_NONE,
                _ENTITY_NONE,
                e1,
                e2
            )
        elif (e1.is_arc() or e1.is_cubic()) and (e2.is_arc() or e2.is_cubic()):
            if (e1.is_arc() or e2.is_arc()) and wp is _WP_FREE_IN_3D:
                raise ValueError("this is a 2d constraint")
            self.add_constraint(
                CURVE_CURVE_TANGENT,
                wp,
                0.,
                _ENTITY_NONE,
                _ENTITY_NONE,
                e1,
                e2
            )
        else:
            raise TypeError(f"unsupported entities: {e1}, {e2}, {wp}")

    cpdef void distance_proj(self, Entity e1, Entity e2, double value):
        """Projected distance constraint between two 3d points."""
        if e1.is_point_3d() and e2.is_point_3d():
            self.add_constraint(
                CURVE_CURVE_TANGENT,
                _WP_FREE_IN_3D,
                value,
                e1,
                e2,
                _ENTITY_NONE,
                _ENTITY_NONE
            )
        else:
            raise TypeError(f"unsupported entities: {e1}, {e2}")

    cpdef void dragged(self, Entity e1, Entity wp = _WP_FREE_IN_3D):
        """Dragged constraint of a point."""
        if e1.is_point():
            self.add_constraint(
                WHERE_DRAGGED,
                wp,
                0.,
                e1,
                _ENTITY_NONE,
                _ENTITY_NONE,
                _ENTITY_NONE
            )
        else:
            raise TypeError(f"unsupported entities: {e1}, {wp}")
