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

--  Package for arbitrary constants. Just stuff'em here, and hope for the
--  best in a future refactoring.

package PBX.Magic_Constants is
   --  Originate options:
   Origination_Caller_Id_Name   : constant String :=
     "origination_caller_id_name";
   Origination_Caller_Id_Number : constant String :=
     "origination_caller_id_number";
   Originate_Timeout            : constant String :=
     "originate_timeout";
   Return_Ring_Ready            : constant String :=
     "return_ring_ready";

   Reception_ID     : constant String := "reception_id";
   Owner            : constant String := "owner";
   Organization_ID  : constant String := "organization_id";
   Contact_ID       : constant String := "contact_id";
   FIFO             : constant String := "fifo";
   Separator        : constant String := "::";
   FIFO_Info        : constant String := FIFO & Separator & "info";
   FIFO_Push        : constant String := "push";
   FIFO_Abort       : constant String := "abort";
   FIFO_Pop         : constant String := "caller_pop";
   Sofia            : constant String := "sofia";
   Sofia_Register   : constant String := Sofia & Separator & "register";
   Sofia_Unregister : constant String := Sofia & Separator & "unregister";
   Park_Prefix      : constant String := "parking_lot";
   Namespace        : constant String := "AdaHeads";
   Prequeue_Enter   : constant String :=
     Namespace & Separator & "pre-queue-enter";
   Prequeue_Leave   : constant String :=
     Namespace & Separator & "pre-queue-leave";
   Waitqueue_Enter  : constant String :=
     Namespace & Separator & "wait-queue-enter";
   Waitqueue_Leave  : constant String :=
     Namespace & Separator & "wait-queue-leave";
   Parking_Lot_Enter  : constant String :=
     Namespace & Separator & "parking-lot-enter";
   Parking_Lot_Leave  : constant String :=
     Namespace & Separator & "parking-lot-leave";
   Outbound_Call      : constant String :=
     Namespace & Separator & "outbound-call";
   Greeting_Played    : constant String :=
     Namespace & Separator & "Greeting-Played";
end PBX.Magic_Constants;
