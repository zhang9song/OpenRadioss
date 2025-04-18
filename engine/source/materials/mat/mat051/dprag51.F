Copyright>        OpenRadioss
Copyright>        Copyright (C) 1986-2025 Altair Engineering Inc.
Copyright>
Copyright>        This program is free software: you can redistribute it and/or modify
Copyright>        it under the terms of the GNU Affero General Public License as published by
Copyright>        the Free Software Foundation, either version 3 of the License, or
Copyright>        (at your option) any later version.
Copyright>
Copyright>        This program is distributed in the hope that it will be useful,
Copyright>        but WITHOUT ANY WARRANTY; without even the implied warranty of
Copyright>        MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
Copyright>        GNU Affero General Public License for more details.
Copyright>
Copyright>        You should have received a copy of the GNU Affero General Public License
Copyright>        along with this program.  If not, see <https://www.gnu.org/licenses/>.
Copyright>
Copyright>
Copyright>        Commercial Alternative: Altair Radioss Software
Copyright>
Copyright>        As an alternative to this open-source version, Altair also offers Altair Radioss
Copyright>        software under a commercial license.  Contact Altair to discuss further if the
Copyright>        commercial version may interest you: https://www.altair.com/radioss/.
      !||====================================================================
      !||    dprag51    ../engine/source/materials/mat/mat051/dprag51.F
      !||--- called by ------------------------------------------------------
      !||    sigeps51   ../engine/source/materials/mat/mat051/sigeps51.F90
      !||====================================================================
      SUBROUTINE DPRAG51
     .          (NEL    ,SIGD   ,VOL      ,EPSEQ  ,
     .           DEPS   ,UPARAM ,VOLUME   ,EINT   , EPX    ,
     .           UVAR   ,NUVAR  ,KK       ,RHO0   ,
     .           C0     ,C1     ,C2       ,C3     , PFRAC  ,PP     ,
     .           OFF    ,PEXT   ,TIMESTEP ,DE )


!common points with M10LAW()
        !SIGD   = deviatoric stress
        !T      = SIGD copy
        !G*DEPSXX = G * DT1*D1

C-----------------------------------------------
C   I m p l i c i t   T y p e s
C-----------------------------------------------
#include      "implicit_f.inc"
C-----------------------------------------------
C   C o m m o n   B l o c k s
C-----------------------------------------------
#include      "com08_c.inc"
C-----------------------------------------------
C   I N P U T   O U T P U T   A r g u m e n t s
C-----------------------------------------------
      INTEGER,INTENT(IN) :: NEL
      my_real, INTENT(IN) :: RHO0,PFRAC,OFF(NEL), DEPS(6,NEL),
     .   VOL(NEL),UPARAM(*) ,VOLUME(NEL),
     .   EPX(NEL),TIMESTEP, PEXT , DE(NEL)
      my_real,INTENT(INOUT) :: SIGD(6,NEL),PP(NEL),EINT(NEL)
C-----------------------------------------------
C   L o c a l   V a r i a b l e s
C-----------------------------------------------
      INTEGER I,KK,NUVAR
       my_real
     .   GG,A0,A1,A2,AMAX,TMELT,THETL,AMUMX,SIGMX,
     .   T0,FACT,FAC2,
     .   UVAR(NEL,NUVAR),
     .   C0, C1, C2, C3, MAS, PTOT
      my_real
     .   YOUNG, NU,
     .   DF(NEL), AMU(NEL), POLD(NEL), AMU2(NEL),
     .   T1(NEL), T2(NEL), T3(NEL), T4(NEL), T5(NEL), T6(NEL),
     .   P(NEL), PNE1(NEL),  RATIO(NEL),
     .   BULK(NEL), BULK2(NEL), G(NEL), G43(NEL), G0(NEL), G2(NEL),
     .   AJ2(NEL),YIELD2(NEL), EPSEQ(NEL),
     .   RHO_NEW(NEL), RHO_OLD(NEL),VNEW(NEL),PSTAR,SIGDO(6,NEL)

C
      A0           = UPARAM(16)
      A1           = UPARAM(17)
      A2           = UPARAM(18)
      AMAX         = UPARAM(19)
      YOUNG        = UPARAM(02)
      NU           = UPARAM(22)
      PSTAR        = UPARAM(23)
      TMELT        = UPARAM(08)
      THETL        = UPARAM(09)
      AMUMX        = UPARAM(20)
      SIGMX        = UPARAM(11)
      T0           = UPARAM(13)
      GG           = UPARAM(01)
      BULK(1:NEL)  = UPARAM(21)
      BULK2(1:NEL) = UPARAM(21)
C
      if(timestep==zero)return
      DO I=1,NEL
        POLD(I)    = UVAR(I,18+KK)
        RHO_OLD(I) = UVAR(I,12+KK)
        VNEW(I)    = UVAR(I,1+KK)*VOLUME(I) -TIMESTEP*UVAR(I,13+KK)
        VNEW(I)    = MIN(MAX(ZERO,VNEW(I)),VOLUME(I))
        IF(VNEW(I)>EM15)THEN
          RHO_NEW(I) = UVAR(I,9+KK) / VNEW(I)  !MASS/VOLUME
        ELSE
          RHO_NEW(I)=RHO_OLD(I)
        ENDIF

        G(I)    = GG !* DT1
        G2(I)   = TWO * G(I)
        G43(I)  = ONEP333*GG
        MAS     = UVAR(I,9+KK)
        IF(MAS>=EM20)THEN
          DF(I)   = RHO_NEW(I)/RHO0
          AMU(I)  = DF(I)-ONE
          AMU2(I) = AMU(I) * MAX(ZERO,AMU(I))
        ELSE
          AMU(I)  = ZERO
          AMU2(I) = ZERO
        ENDIF

        T1(I)=SIGD(1,I)
        T2(I)=SIGD(2,I)
        T3(I)=SIGD(3,I)
        T4(I)=SIGD(4,I)
        T5(I)=SIGD(5,I)
        T6(I)=SIGD(6,I)

        IF(EPX(I)<0)BULK2(I)=C1   !nok passer epx en argument et initialiser
        IF(AMU(I)<0)BULK(I) =C1

        P(I)=C0+C1*AMU(I)+C2*AMU2(I)+C3*AMU2(I)*AMU(I)
        PNE1(I)=POLD(I)+AMU(I)*BULK2(I)-EPX(I)*BULK(I)

!UNLOAD BEHAVIOR
!        IF(AMU(I)<AMUMX) P(I) = MIN(P(I),PNE1(I))
        FAC2 = ONE
        IF(P(I)<PFRAC)THEN
!         !EPX(I) =EPX(I)+(PFRAC-POLD(I))/BULK2(I)
          P(I)  = PFRAC
          FAC2 = ZERO
!        ELSE
!          EPX(I) =AMU(I)
        ENDIF
        PP(I) = P(I)

        SIGDO(1:6,I) = SIGD(1:6,I) * OFF(I)
        FACT = VOL(I)/VOLUME(I)
        T1(I) = T1(I) + G2(I)* (DEPS(1,I)-DE(I))*FACT
        T2(I) = T2(I) + G2(I)* (DEPS(2,I)-DE(I))*FACT
        T3(I) = T3(I) + G2(I)* (DEPS(3,I)-DE(I))*FACT
        T4(I) = T4(I) + G(I) * DEPS(4,I)*FACT
        T5(I) = T5(I) + G(I) * DEPS(5,I)*FACT
        T6(I) = T6(I) + G(I) * DEPS(6,I)*FACT

        AJ2(I)=HALF*(T1(I)**2+T2(I)**2+T3(I)**2)+T4(I)**2+T5(I)**2+T6(I)**2
        PTOT = P(I)+PEXT
        G0(I) =A0+A1*PTOT+A2*PTOT*PTOT
        G0(I)= MIN(AMAX,FAC2*G0(I))    !FAC2=1 ou 0 si P<Pmin
        G0(I)= MAX(ZERO,G0(I))
        IF(PTOT <= PSTAR)G0(I)=ZERO
        YIELD2(I)=AJ2(I)-G0(I)

        RATIO(I)=ZERO
        IF(YIELD2(I)<=ZERO .AND. G0(I)>ZERO)THEN
          RATIO(I)=ONE
        ELSE
          RATIO(I)=SQRT(G0(I)/(AJ2(I)+ EM14))
        ENDIF

        ! il s'agit ici du deviateur du sous materiau stocke dans UVAR
        SIGD(1,I)=RATIO(I)*T1(I)*OFF(I)
        SIGD(2,I)=RATIO(I)*T2(I)*OFF(I)
        SIGD(3,I)=RATIO(I)*T3(I)*OFF(I)
        SIGD(4,I)=RATIO(I)*T4(I)*OFF(I)
        SIGD(5,I)=RATIO(I)*T5(I)*OFF(I)
        SIGD(6,I)=RATIO(I)*T6(I)*OFF(I)

        if(UVAR(I,1+KK)>EM02)then
        EPSEQ(I)=EPSEQ(I)+(ONE -RATIO(I))*SQRT(ABS(AJ2(I)))*DT1
     .           / MAX(EM20,THREE*TIMESTEP*G(I))
        endif

        EINT(I) = EINT(I) + HALF*(VOL(I))*
     .                    ( (SIGD(1,I)+SIGDO(1,I)) * DEPS(1,I)
     .                    + (SIGD(2,I)+SIGDO(2,I)) * DEPS(2,I)
     .                    + (SIGD(3,I)+SIGDO(3,I)) * DEPS(3,I)
     .                    + (SIGD(4,I)+SIGDO(4,I)) * DEPS(4,I)
     .                    + (SIGD(5,I)+SIGDO(5,I)) * DEPS(5,I)
     .                    + (SIGD(6,I)+SIGDO(6,I)) * DEPS(6,I))

      ENDDO !next I


      RETURN
      END
C
