Private Sub writeName(name As String, indent As String)
  Dim s As String
  s = LCase(Trim(name))
  Select Case Asc(Mid(s, 1, 1))
    Case 65 To 90, 95, 97 To 122
    Case Else
      GoTo longForm
  End Select

  For i = 2 To Len(s)
    Select Case Asc(Mid(s, i, 1))
      Case 48 To 57, 65 To 90, 95, 97 To 122
      Case Else
        GoTo longForm
    End Select
  Next i

  Print #1, indent + s + " =";
  Exit Sub

longForm:
  Print #1, indent + "['" + LCase(Trim(name)) + "'] =";
End Sub

Private Sub writeVal(val As Variant)
  If IsNumeric(val) Then
    Print #1, val;
  Else
    Print #1, " '" + val + "'";
  End If
  Print #1, ","
End Sub

Sub SaveToLua()
  Dim col, elem, lname As String
  Dim ws As Worksheet
  Dim fname As Variant

  fname = Application.GetSaveAsFilename(filefilter:="Lua Files (*.lua),*.lua")
  If fname = False Then
    Exit Sub
  Else
    Open fname For Output As #1

    lastRow = Worksheets("materials").UsedRange.SpecialCells(xlCellTypeLastCell).Row
    lastCol = Worksheets("materials").UsedRange.SpecialCells(xlCellTypeLastCell).Column

    Print #1, "-- automatically generated Lua batch definition"
    Print #1, "return { -- materials"

    namecol = -1
    For i = 1 To lastCol
      If Worksheets("materials").Cells(1, i) = "name" Then
        namecol = i
      End If
    Next i
    If namecol < 0 Then
      MsgBox "Error: no column 'name'"
      Exit Sub
    Else
      For i = 2 To lastRow
        If CStr(Worksheets("materials").Cells(i, namecol)) <> "" Then
          Call writeName(CStr(Worksheets("materials").Cells(i, namecol)), "  ")
          Print #1, " {"
          For j = 1 To lastCol
            col = CStr(Worksheets("materials").Cells(1, j))
            elem = CStr(Worksheets("materials").Cells(i, j))
            If col <> "" And elem <> "" Then
              Call writeName(Worksheets("materials").Cells(1, j), "    ")
              Call writeVal(Worksheets("materials").Cells(i, j))
            End If
          Next j
          Print #1, "  },"
        End If
      Next i
    End If

    Print #1, "}, { -- recipes"
    For Each ws In ActiveWorkbook.Worksheets
      If ws.name <> "materials" And ws.name <> "recipes" Then
        lname = LCase(Trim(ws.name))
        Call writeName(lname, "  ")
        Print #1, " {"
        
        lastRow = Worksheets("recipes").UsedRange.SpecialCells(xlCellTypeLastCell).Row
        lastCol = Worksheets("recipes").UsedRange.SpecialCells(xlCellTypeLastCell).Column
        For i = 2 To lastRow
          If LCase(Trim(Worksheets("recipes").Cells(i, 1))) = lname Then
            For j = 1 To lastCol
              Call writeName(CStr(Worksheets("recipes").Cells(1, j)), "    ")
              Call writeVal(Worksheets("recipes").Cells(i, j))
            Next j
          End If
        Next i
        
        lastRow = ws.UsedRange.SpecialCells(xlCellTypeLastCell).Row
        lastCol = ws.UsedRange.SpecialCells(xlCellTypeLastCell).Column
        For i = 2 To lastRow
          Print #1, "    [" + CStr(i - 1) + "] = {"
          For j = 1 To lastCol
            col = CStr(ws.Cells(1, j))
            elem = CStr(ws.Cells(i, j))
            If col <> "" And elem <> "" Then
              Call writeName(ws.Cells(1, j), "      ")
              Call writeVal(ws.Cells(i, j))
            End If
          Next j
          Print #1, "    },"
        Next i
        Print #1, "  },"
      End If
    Next ws
    Print #1, "}"
    Close #1
  End If
End Sub

