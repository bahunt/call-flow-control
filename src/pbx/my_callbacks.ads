with AMI;
with AMI.Parser;

package My_Callbacks is
   use AMI.Parser;

   Package_Name : constant String := "My_Callbacks";

   NOT_IMPLEMENTED              : exception;

   --  Callbacks
   procedure Peer_Status (Packet : in Packet_Type);

   procedure Dial        (Packet : in Packet_Type);
   procedure Hangup      (Packet : in Packet_Type);
   procedure Join        (Packet : in Packet_Type);
   procedure New_Channel (Packet : in Packet_Type);
   procedure New_State   (Packet : in Packet_Type);

   procedure Queue_Abandon (Packet : in Packet_Type);
   --  procedure Unlink_Callback     (Event_List : in Event_List_Type.Map);

   procedure SIPPeers;
   procedure NewState;
   procedure Bridge;
   procedure Agents;

end My_Callbacks;