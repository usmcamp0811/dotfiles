// comp: mapping for_if_clause
//
// mapping: expression
//
// for_if_clause:
//      | 'for' pattern 'in' expression ('if' expression)*
//
// pattern: name (, name)*
use proc_macro2::TokenStream as TokenStream2;
use quote::quote;
use syn::{
    parse::{Parse, ParseStream},
    Token,
};

struct Comp {
    mapping: Mapping,
    for_if_clause: ForIfClause,
}

impl Parse for Comp {
    fn parse(input: ParseStream) -> syn::Result<Self> {
        Ok(Self {
            mapping: input.parse()?,
            for_if_clause: input.parse()?,
        })
    }
}

impl quote::ToTokens for Comp {
    fn to_tokens(&self, tokens: &mut TokenStream2) {
        let Mapping(mapping) = &self.mapping;
        let ForIfClause {
            pattern,
            expression,
            conditions,
        } = &self.for_if_clause;

        let conditions = conditions.into_iter().map(|c| {
            let inner = &c.0;
            quote! { #inner }
        });
        tokens.extend(quote! {
            core::iter::IntoIterator::into_iter(#expression).filter_map(move |#pattern| {
                (true #(&& (#expression))*).then(|| #mapping)
            })
        });
    }
}

struct Mapping(syn::Expr);

impl Parse for Mapping {
    fn parse(input: ParseStream) -> syn::Result<Self> {
        Ok(Self(input.parse()?))
    }
}

impl quote::ToTokens for Mapping {
    fn to_tokens(&self, tokens: &mut TokenStream2) {
        self.0.to_tokens(tokens);
    }
}

struct ForIfClause {
    pattern: Pattern,
    expression: syn::Expr,
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
            expression,
            conditions,
        })
    }
}

fn parse_zero_or_more<T: Parse>(input: ParseStream) -> Vec<T> {
    let mut result: Vec<T> = Vec::new();
    while let Ok(item) = input.parse() {
        result.push(item);
    }
    retult
}

struct Pattern(syn::Pat);

impl Parse for Pattern {
    fn parse(input: ParseStream) -> syn::Result<Self> {
        input.call(syn::Pat::parse_single).map(Self)
    }
}

impl quote::ToTokens for Pattern {
    fn to_tokens(&self, tokens: &mut TokenStream2) {
        // TODO: ask Chat to explain this
        self.0.to_tokens(tokens);
    }
}

struct Condition(syn::Expr);

impl Parse for Condition {
    fn parse(input: ParseStream) -> syn::Result<Self> {
        // parse if?

        // _ = input.parse::<syn::Token![if]>()?; // this does the same as
        let _: syn::Token![if] = input.parse()?; // this
        input.parse().map(Self)
    }
}

// impl ToTokens for Condition {
//     fn to_tokens(&self, tokens: &mut TokenStream2) {
//         self.0.to_tokens(tokens);
//     }
// }
