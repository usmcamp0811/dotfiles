// comp: mapping for_if_clause
//
// mapping: expression
//
// for_if_clause:
//      | 'for' pattern 'in' expression ('if' expression)*
//
// pattern: name (, name)*
use proc_macro2::TokenStream as TokenStream2;
use quote::{quote, ToTokens};
use syn::{
    parse::{Parse, ParseStream},
    parse_macro_input, Expr, Pat, Token,
};

struct Comprehension {
    mapping: Mapping,
    for_if_clause: ForIfClause,
    additional_for_if_clauses: Vec<ForIfClause>,
}

impl Parse for Comprehension {
    fn parse(input: ParseStream) -> syn::Result<Self> {
        Ok(Self {
            mapping: input.parse()?,
            for_if_clause: input.parse()?,
            additional_for_if_clauses: parse_zero_or_more(input),
        })
    }
}

impl ToTokens for Comprehension {
    fn to_tokens(&self, tokens: &mut TokenStream2) {
        let all_for_if_clauses =
            std::iter::once(&self.for_if_clause).chain(&self.additional_for_if_clauses);
        let mut innermost_to_outermost = all_for_if_clauses.rev();

        let mut output = {
            // innermost is a special case--here we do the mapping
            let innermost = innermost_to_outermost
                .next()
                .expect("We know we have at least one ForIfClause (self.for_if_clause)");
            let ForIfClause {
                pattern,
                sequence,
                conditions,
            } = innermost;

            let Mapping(mapping) = &self.mapping;

            quote! {
                core::iter::IntoIterator::into_iter(#sequence).filter_map(move |#pattern| {
                    (true #(&& (#conditions))*).then(|| #mapping)
                })
            }
        };

        // Now we walk through the rest of the ForIfClauses, wrapping the current `output` in a new layer of iteration each time.
        // We also add an extra call to '.flatten()'.
        output = innermost_to_outermost.fold(output, |current_output, next_layer| {
            let ForIfClause {
                pattern,
                sequence,
                conditions,
            } = next_layer;
            quote! {
                core::iter::IntoIterator::into_iter(#sequence).filter_map(move |#pattern| {
                    (true #(&& (#conditions))*).then(|| #current_output)
                })
                .flatten()
            }
        });

        tokens.extend(output)
    }
}

struct Mapping(Expr);

impl Parse for Mapping {
    fn parse(input: ParseStream) -> syn::Result<Self> {
        input.parse().map(Self)
    }
}

impl quote::ToTokens for Mapping {
    fn to_tokens(&self, tokens: &mut TokenStream2) {
        self.0.to_tokens(tokens);
    }
}

struct ForIfClause {
    pattern: Pattern,
    sequence: Expr,
    conditions: Vec<Condition>,
}

impl Parse for ForIfClause {
    fn parse(input: ParseStream) -> syn::Result<Self> {
        _ = input.parse::<syn::Token![for]>()?;
        let pattern = input.parse()?;
        _ = input.parse::<Token![in]>()?;
        let sequence = input.parse()?;
        let conditions = parse_zero_or_more(input);
        Ok(Self {
            pattern,
            sequence,
            conditions,
        })
    }
}

fn parse_zero_or_more<T: Parse>(input: ParseStream) -> Vec<T> {
    let mut result: Vec<T> = Vec::new();
    while let Ok(item) = input.parse() {
        result.push(item);
    }
    result
}

struct Pattern(Pat);

impl Parse for Pattern {
    fn parse(input: ParseStream) -> syn::Result<Self> {
        input.call(syn::Pat::parse_single).map(Self)
    }
}

impl ToTokens for Pattern {
    fn to_tokens(&self, tokens: &mut TokenStream2) {
        // TODO: ask Chat to explain this
        self.0.to_tokens(tokens);
    }
}

struct Condition(Expr);

impl Parse for Condition {
    fn parse(input: ParseStream) -> syn::Result<Self> {
        // parse if?

        // _ = input.parse::<syn::Token![if]>()?; // this does the same as
        let _: syn::Token![if] = input.parse()?; // this
        input.parse().map(Self)
    }
}

impl ToTokens for Condition {
    fn to_tokens(&self, tokens: &mut TokenStream2) {
        self.0.to_tokens(tokens)
    }
}

#[proc_macro]
pub fn comp(input: proc_macro::TokenStream) -> proc_macro::TokenStream {
    let c = parse_macro_input!(input as Comprehension);
    quote! { #c }.into()
}
