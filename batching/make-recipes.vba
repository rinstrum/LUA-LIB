Sub SaveToLua()
  Dim col, elem As String
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
          Print #1, "  ['" + LCase(Trim(CStr(Worksheets("materials").Cells(i, namecol)))) + "'] = {"
          For j = 1 To lastCol
            col = CStr(Worksheets("materials").Cells(1, j))
            elem = CStr(Worksheets("materials").Cells(i, j))
            If col <> "" And elem <> "" Then
              Print #1, "    ['" + col + "'] =";
              If IsNumeric(Worksheets("materials").Cells(i, j)) Then
                Print #1, Worksheets("materials").Cells(i, j);
              Else
                Print #1, " '" + elem + "'";
              End If
              Print #1, ","
            End If
          Next j
          Print #1, "  },"
        End If
      Next i
    End If

    Print #1, "}, { -- recipes"
    For Each ws In ActiveWorkbook.Worksheets
      If ws.Name <> "materials" Then
        Print #1, "  ['" + LCase(Trim(ws.Name)) + "'] = {"
        lastRow = ws.UsedRange.SpecialCells(xlCellTypeLastCell).Row
        lastCol = ws.UsedRange.SpecialCells(xlCellTypeLastCell).Column
        For i = 2 To lastRow
          Print #1, "    [" + CStr(i - 1) + "] = {"
          For j = 1 To lastCol
            col = CStr(ws.Cells(1, j))
            elem = CStr(ws.Cells(i, j))
            If col <> "" And elem <> "" Then
              Print #1, "      ['" + col + "'] =";
              If IsNumeric(ws.Cells(i, j)) Then
                Print #1, ws.Cells(i, j);
              Else
                Print #1, " '" + elem + "'";
              End If
              Print #1, ","
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

