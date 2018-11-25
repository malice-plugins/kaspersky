package main

const tpl = `#### Kaspersky
{{- with .Results }}
| Infected      | Result      | Engine      | Updated      |
|:-------------:|:-----------:|:-----------:|:------------:|
| {{.Infected}} | {{.Result}} | {{.Engine}} | {{.Updated}} |
{{ end -}}
`

// func printMarkDownTable(bitdefender Kaspersky) {
//
// 	fmt.Println("#### Kaspersky")
// 	table := clitable.New([]string{"Infected", "Result", "Engine", "Updated"})
// 	table.AddRow(map[string]interface{}{
// 		"Infected": bitdefender.Results.Infected,
// 		"Result":   bitdefender.Results.Result,
// 		"Engine":   bitdefender.Results.Engine,
// 		"Updated":  bitdefender.Results.Updated,
// 	})
// 	table.Markdown = true
// 	table.Print()
// }
