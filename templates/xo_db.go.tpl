// XODB is the common interface for database operations that can be used with
// types from {{ .Schema }}.
//
// This should work with database/sql.DB and database/sql.Tx.
type XODB interface {
	Exec(string, ...interface{}) (sql.Result, error)
	Query(string, ...interface{}) (*sql.Rows, error)
	QueryRow(string, ...interface{}) *sql.Row
}

// ScannerValuer is the common interface for types that implement both the
// database/sql.Scanner and sql/driver.Valuer interfaces.
type ScannerValuer interface {
    sql.Scanner
    driver.Valuer
}

// StringSlice is a slice of strings.
type StringSlice []string

// quoteEscapeRegex is the regex to match escaped characters in a string.
var quoteEscapeRegex = regexp.MustCompile(`([^\\]([\\]{2})*)\\"`)

// Scan satisfies the sql.Scanner interface for StringSlice.
func (ss *StringSlice) Scan(src interface{}) error {
    buf, ok := src.([]byte)
    if !ok {
        return errors.New("invalid StringSlice")
    }

    // change quote escapes for csv parser
    str := quoteEscapeRegex.ReplaceAllString(string(buf), `$1""`)
    str = strings.Replace(str, `\\`, `\`, -1)

    // remove braces
    str = str[1:len(str)-1]

    // bail if only one
    if len(str) == 0 {
        *ss = StringSlice([]string{})
        return nil
    }

    // parse with csv reader
    cr := csv.NewReader(strings.NewReader(str))
    slice, err := cr.Read()
    if err != nil {
        fmt.Printf("exiting!: %v\n", err)
        return err
    }

    *ss = StringSlice(slice)

    return nil
}

// Value satisfies the driver.Valuer interface for StringSlice.
func (ss StringSlice) Value() (driver.Value, error) {
    for i, s := range ss {
        ss[i] = `"` + strings.Replace(strings.Replace(s, `\`, `\\\`, -1), `"`, `\"`, -1) + `"`
    }
    return "{" + strings.Join(ss, ",") + "}", nil
}

// Slice is a slice of ScannerValuers.
type Slice []ScannerValuer

