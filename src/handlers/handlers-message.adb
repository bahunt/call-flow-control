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

with Ada.Strings.Fixed;

with AWS.Parameters,
     AWS.Status,
     AWS.Utils,
     GNATCOLL.JSON;

with Common,
     HTTP_Codes,
     MIME_Types,
     Model,
     Model.Contact,
     System_Message.Debug,
     View;

package body Handlers.Message is
   subtype Contact_In_Organization is Model.Organization_Contact_Identifier;

   function Image (Item : in Model.Contact_Identifier) return String;
   function Image (Item : in Model.Organization_Identifier) return String;
   function Image (Item : in Contact_In_Organization) return String;

   function Image (Item : in Model.Contact_Identifier) return String is
      use Ada.Strings, Ada.Strings.Fixed;
   begin
      return Trim (Model.Contact_Identifier'Image (Item), Both);
   end Image;

   function Image (Item : in Model.Organization_Identifier) return String is
      use Ada.Strings, Ada.Strings.Fixed;
   begin
      return Trim (Model.Organization_Identifier'Image (Item), Both);
   end Image;

   function Image (Item : in Contact_In_Organization) return String is
   begin
      return
        "<" & Image (Item.Contact_ID) &
        "@" & Image (Item.Organization_ID) & ">";
   end Image;

   package Parser is
      type Instance (<>) is tagged private;

      function Create (Source : in     String) return Instance'Class;
      procedure Get_Next (Source  : in out Instance;
                          Found   :    out Boolean;
                          Error   :    out Boolean;
                          Contact :    out Contact_In_Organization);
   private
      type Instance (Length : Natural) is tagged
         record
            Source : String (1 .. Length);
            Last   : Natural := 0;
         end record;
   end Parser;

   package body Parser is
      function Just_Before (Source  : in     String;
                            Pattern : in     String) return Natural;

      function Create (Source : in     String) return Instance'Class is
      begin
         return Result : Instance (Length => Source'Length) do
            Result.Source := Source;
         end return;
      exception
         when Constraint_Error =>
            raise Constraint_Error
              with "Handlers.Message.Parser.Create failed.";
      end Create;

      procedure Get_Next (Source  : in out Instance;
                          Found   :    out Boolean;
                          Error   :    out Boolean;
                          Contact :    out Contact_In_Organization) is
         Next : Natural;
      begin
         System_Message.Debug.Leaving_Subprogram
           (Message => "Get_Next: Source = (Source => """ & Source.Source &
                       """, Last =>" & Natural'Image (Source.Last) & ")");

         if Source.Last >= Source.Length then
            Found := False;
         else
            Next := Just_Before (Source.Source (Source.Last + 1 ..
                                                Source.Length), "@");
            Contact.Contact_ID :=
              Model.Contact_Identifier'Value
                (Source.Source (Source.Last + 1 .. Next));
            Source.Last := Next + 1;

            Next := Just_Before (Source.Source (Source.Last + 1 ..
                                                Source.Length), ",");
            Contact.Organization_ID :=
              Model.Organization_Identifier'Value
                (Source.Source (Source.Last + 1 .. Next));
            Source.Last := Next + 1;

            Found := True;
         end if;

         Error := False;
      exception
         when E : others =>
            System_Message.Debug.Leaving_Subprogram
              (Event   => E,
               Message => "Get_Next: Source = (Source => """ & Source.Source &
                          """, Last =>" & Natural'Image (Source.Last) &
                          "), Next =" & Natural'Image (Next));

            Source.Last := Source.Length;
            Found := False;
            Error := True;
      end Get_Next;

      function Just_Before (Source  : in     String;
                            Pattern : in     String) return Natural is
         use Ada.Strings.Fixed;
         Position : Natural;
      begin
         Position := Index (Source, Pattern);
         if Position = 0 then
            System_Message.Debug.Leaving_Subprogram
              (Message => "Just_Before found """ & Pattern & """ just after position" & Natural'Image (Source'Last) & " in """ & Source & """ (indexed from" & Positive'Image (Source'First) & " to" & Natural'Image (Source'Last) & ").");
            return Source'Last;
         else
            System_Message.Debug.Leaving_Subprogram
              (Message => "Just_Before found """ & Pattern & """ just after position" & Natural'Image (Position - 1) & " in """ & Source & """ (indexed from" & Positive'Image (Source'First) & " to" & Natural'Image (Source'Last) & ").");
            return Position - 1;
         end if;
      exception
         when E : others =>
            System_Message.Debug.Leaving_Subprogram
              (Event   => E,
               Message => "Just_Before: Source = """ & Source &
                          """, Pattern = """ & Pattern & """, Position =" &
                          Natural'Image (Position));
            raise;
      end Just_Before;
   end Parser;

   package body Send is
      function Service (Request : in AWS.Status.Data) return AWS.Response.Data;

      function Callback return AWS.Response.Callback is
      begin
         return Service'Access;
      end Callback;

      function Service (Request : in AWS.Status.Data)
                       return AWS.Response.Data is
         use GNATCOLL.JSON;
         use Common;

         Parameters : AWS.Parameters.List
                        renames AWS.Status.Parameters (Request);

         function Bad_Or_Missing_Message return Boolean;
         function No_Contacts_Selected return Boolean;
         function Contact_Does_Not_Exist
                    (ID :    out Contact_In_Organization) return Integer;
         --  function Contact_Does_Not_Exist
         --             (ID :    out Contact_In_Organization) return Boolean;
         function Contact_Without_Messaging_Addresses
                    (ID :    out Contact_In_Organization) return Boolean;

         function Bad_Or_Missing_Message return AWS.Response.Data;
         function No_Contacts_Selected return AWS.Response.Data;
         function Contact_Does_Not_Exist
                    (ID : in     Contact_In_Organization)
                    return AWS.Response.Data;
         function Contact_Without_Messaging_Addresses
                    (ID : in     Contact_In_Organization)
                    return AWS.Response.Data;
         function Message_Sent return AWS.Response.Data;

         function Bad_Or_Missing_Message return Boolean is
         begin
            return not
              (
                 Parameters.Exist ("message") and then
                 Parameters.Get ("message")'Length > 0 and then
                 AWS.Utils.Is_Valid_UTF8 (Parameters.Get ("message"))
              );
         end Bad_Or_Missing_Message;

         function Bad_Or_Missing_Message return AWS.Response.Data is
            Data : JSON_Value;
         begin
            Data := Create_Object;

            Data.Set_Field (Field_Name => View.Status,
                            Field      => "bad request");
            Data.Set_Field (Field_Name => View.Description,
                            Field      => "passed message argument is too " &
                                          "long, missing or invalid");

            return AWS.Response.Build
              (Content_Type => MIME_Types.JSON,
               Message_Body => To_String (To_JSON_String (Data)),
               Status_Code  => HTTP_Codes.Bad_Request);
         end Bad_Or_Missing_Message;

         function Contact_Does_Not_Exist
           (ID :    out Contact_In_Organization) return Integer is
         --  function Contact_Does_Not_Exist
         --    (ID :    out Contact_In_Organization) return Boolean is
            procedure Look_Up (Contacts  : in     String;
                               Found_All :    out Boolean;
                               Missing   :    out Contact_In_Organization);
            procedure Look_Up (Contacts  : in     String;
                               Found_All :    out Boolean;
                               Missing   :    out Contact_In_Organization) is
               function Exists_In_Database
                          (Item : in Contact_In_Organization) return Boolean;
               function Exists_In_Database
                          (Item : in Contact_In_Organization) return Boolean is
               begin
                  System_Message.Debug.Entered_Subprogram
                    (Message => "Exists_In_Database (Item => " & Image (Item) & ")?");

                  declare
                     use type Model.Contact_Identifier;
                     Contact : constant Model.Contact.Object :=
                                 Model.Contact.Get (Item);
                  begin
                     System_Message.Debug.Leaving_Subprogram
                       (Message => "return " & Boolean'Image (Contact.ID = Item.Contact_ID));

                     return Contact.ID = Item.Contact_ID;
                  end;
               exception
                  when E : others =>
                     System_Message.Debug.Leaving_Subprogram
                       (Message => "return False");
                     System_Message.Debug.Leaving_Subprogram
                       (Event   => E,
                        Message => "Handlers.Message.Send." &
                                   "Contact_Does_Not_Exist.Look_Up");
                     return False;
               end Exists_In_Database;

               List    : Parser.Instance'Class := Parser.Create (Contacts);
               Found   : Boolean;
               Contact : Contact_In_Organization;
               Error   : Boolean;
            begin
               Check_Contacts :
               loop
                  List.Get_Next (Found   => Found,
                                 Contact => Contact,
                                 Error   => Error);

                  if Error then
                     raise Program_Error
                       with "Logic error in Handlers.Message.Send: " &
                            "Could not parse contact list.";
                  elsif Found then
                     if Exists_In_Database (Contact) then
                        System_Message.Debug.Jacob_Wants_To_See_This
                          (Message => "Found " & Image (Contact) & ".");
                        null;
                     else
                        System_Message.Debug.Jacob_Wants_To_See_This
                          (Message => "Could not find " & Image (Contact) & ".");

                        Found_All := False;
                        Missing := Contact;
                        exit Check_Contacts;
                     end if;
                  else
                     Found_All := True;
                     exit Check_Contacts;
                  end if;
               end loop Check_Contacts;

               System_Message.Debug.Leaving_Subprogram
                 (Message => "Contacts => """ & Contacts & """, Found_All => " & Boolean'Image (Found_All) & ", Missing => " & Image (Missing) & ".");
            end Look_Up;

            Result : Boolean := False;
            Okay : Boolean;
         begin
            ID := (0, 0); --  Should really make ID a conditional variable.

            if Parameters.Exist ("to") then
               Look_Up (Contacts  => Parameters.Get ("to"),
                        Found_All => Okay,
                        Missing   => ID);
               if not Okay then
                  System_Message.Debug.Leaving_Subprogram
                    (Message => "1: Could not find " & Image (ID) & " in database.");
                  Result := True; --  return True;
               end if;
            end if;

            if not Result and then Parameters.Exist ("cc") then
               Look_Up (Contacts  => Parameters.Get ("cc"),
                        Found_All => Okay,
                        Missing   => ID);
               if not Okay then
                  Result := True; --  return True;
               end if;
            end if;

            if not Result and then Parameters.Exist ("bcc") then
               Look_Up (Contacts  => Parameters.Get ("bcc"),
                        Found_All => Okay,
                        Missing   => ID);
               if not Okay then
                  Result := True; --  return True;
               end if;
            end if;

            System_Message.Debug.Leaving_Subprogram
              (Message => "Contact_Does_Not_Exist returns " & Boolean'Image (Result));
            if Result then
               return 42;
            else
               return -1;
            end if;
            --return Result; --  False;
         end Contact_Does_Not_Exist;

         function Contact_Does_Not_Exist
                    (ID : in     Contact_In_Organization)
                    return AWS.Response.Data is
            Data : JSON_Value;
         begin
            System_Message.Debug.Entered_Subprogram
              (Message => "Composing Contact_Does_Not_Exist response.");

            Data := Create_Object;

            Data.Set_Field (Field_Name => View.Status,
                            Field      => "not_found");
            Data.Set_Field (Field_Name => View.Description,
                            Field      => "there is no contact with id " &
                                          Image (ID.Contact_ID) & "in the " &
                                          "organization with id "&
                                          Image (ID.Organization_ID) &
                                          "in the database");

            return AWS.Response.Build
              (Content_Type => MIME_Types.JSON,
               Message_Body => To_String (To_JSON_String (Data)),
               Status_Code  => HTTP_Codes.Not_Found);
         exception
            when E : others =>
               System_Message.Debug.Leaving_Subprogram
                 (Event   => E,
                  Message => "Bug in Contact_Does_Not_Exist : AWS.Response.Data");
               raise;
         end Contact_Does_Not_Exist;

         function Contact_Without_Messaging_Addresses
                    (ID :    out Contact_In_Organization) return Boolean is
         begin
            raise Program_Error with "Not implemented yet.";
            return True;
         end Contact_Without_Messaging_Addresses;

         function Contact_Without_Messaging_Addresses
                    (ID : in     Contact_In_Organization)
                    return AWS.Response.Data is
            Data : JSON_Value;
         begin
            Data := Create_Object;

            Data.Set_Field (Field_Name => View.Status,
                            Field      => "not_found");
            Data.Set_Field (Field_Name => View.Description,
                            Field      => "contact " & Image (ID) &
                                          " has no messaging addresses in " &
                                          "the database");

            return AWS.Response.Build
              (Content_Type => MIME_Types.JSON,
               Message_Body => To_String (To_JSON_String (Data)),
               Status_Code  => HTTP_Codes.Not_Found);
         end Contact_Without_Messaging_Addresses;

         function Message_Sent return AWS.Response.Data is
            Data : JSON_Value;
         begin
            Data := Create_Object;

            Data.Set_Field (Field_Name => View.Status,
                            Field      => "not implemented yet");

            return AWS.Response.Build
              (Content_Type => MIME_Types.JSON,
               Message_Body => To_String (To_JSON_String (Data)),
               Status_Code  => HTTP_Codes.Server_Error);
         end Message_Sent;

         function No_Contacts_Selected return Boolean is
         begin
            return not
              (
                 Parameters.Exist ("to") or else
                 Parameters.Exist ("cc") or else
                 Parameters.Exist ("bcc")
              );
         end No_Contacts_Selected;

         function No_Contacts_Selected return AWS.Response.Data is
            Data : JSON_Value;
         begin
            Data := Create_Object;

            Data.Set_Field (Field_Name => View.Status,
                            Field      => "bad request");
            Data.Set_Field (Field_Name => View.Description,
                            Field      => "no contacts selected");

            return AWS.Response.Build
              (Content_Type => MIME_Types.JSON,
               Message_Body => To_String (To_JSON_String (Data)),
               Status_Code  => HTTP_Codes.Bad_Request);
         end No_Contacts_Selected;

         ID : Contact_In_Organization;
      begin
         declare
            Dummy : Integer := -1;
         begin
            Dummy := Contact_Does_Not_Exist (ID);
            System_Message.Debug.Jacob_Wants_To_See_This
              (Message => "Contact_Does_Not_Exist returned " & Integer'Image (Dummy));
         end;

         if Bad_Or_Missing_Message then
            return Bad_Or_Missing_Message;
         elsif No_Contacts_Selected then
            return No_Contacts_Selected;
         elsif Contact_Does_Not_Exist (ID) = 42 then
            System_Message.Debug.Jacob_Wants_To_See_This
              (Message => "3: TRUE");
            return Contact_Does_Not_Exist (ID);
         elsif Contact_Without_Messaging_Addresses (ID) then
            return Contact_Without_Messaging_Addresses (ID);
         else
            --  Send message and then ...
            return Message_Sent;
         end if;
      end Service;
   end Send;
end Handlers.Message;