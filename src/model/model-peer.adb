-------------------------------------------------------------------------------
--                                                                           --
--                     Copyright (C) 2013-, AdaHeads K/S                     --
--                                                                           --
--  This is free software;  you can redistribute it and/or modify it         --
--  under terms of the  GNU General Public License  as published by the      --
--  Free Software  Foundation;  either version 3,  or (at your  option) any  --
--  later version. This library is distributed in the hope that it will be   --
--  useful, but WITHOUT ANY WARRANTY;  without even the implied warranty of  --
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                     --
--  You should have received a copy of the GNU General Public License and    --
--  a copy of the GCC Runtime Library Exception along with this program;     --
--  see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see    --
--  <http://www.gnu.org/licenses/>.                                          --
--                                                                           --
-------------------------------------------------------------------------------

with Ada.Calendar;

package body Model.Peer is
   use Ada.Calendar;

   procedure Bump_Expiry (Object     :    out Instance;
                          Time_Delta : in     Natural) is
   begin
      Object.Expiry_Time := Current_Time + Duration (Time_Delta);
   end Bump_Expiry;

   --------------
   --  Create  --
   --------------

   function Create (User_ID : Identification;
                    Values  : JSON_Value) return Instance is
      Is_Registered : Boolean := False;
   begin
      if Values.Get (Field => Contact_String) (1 .. 5) /= "error" then
         Is_Registered := True;
      end if;

      return (User_ID     => User_ID,
              Values      => Values,
              Registered  => Is_Registered,
              Expiry_Time => <>);
   end Create;

   --------------------------
   --  Get_Identification  --
   --------------------------

   function Get_Identification (Object : in Instance) return String is
   begin
      return Object.Values.Get (Field => Extension_String);
   end Get_Identification;

   ----------------
   --  Register  --
   ----------------

   procedure Register (Object : out Instance) is
   begin
      Object.Registered := True;
   end Register;

   ------------------
   --  Registered  --
   ------------------

   function Registered (Object : in Instance) return Boolean is
   begin
      return Object.Registered;
   end Registered;

   ---------------
   --  To_JSON  --
   ---------------

   function To_JSON (Object : in Instance) return JSON_Value is
      Root       : constant JSON_Value := Create_Object;
      Expires_In : constant Duration :=
        Object.Expiry_Time - Common.Current_Time;
   begin
      if Expires_In < 0.0 then
         Root.Set_Field (Field_Name => Expires_String,
                         Field      => Integer'(0));
      else
         Root.Set_Field (Field_Name => Expires_String,
                         Field      => Integer (Expires_In));
      end if;

      Root.Set_Field (Field_Name => Registered_String,
                      Field      => Object.Registered);
      Root.Set_Field (Field_Name => To_String (Object.User_ID),
                      Field      => Object.Values);
      return Root;
   end To_JSON;

   ------------------
   --  Unregister  --
   ------------------
   procedure Unregister (Object : out Instance) is
   begin
      Object.Registered := False;
   end Unregister;

end Model.Peer;