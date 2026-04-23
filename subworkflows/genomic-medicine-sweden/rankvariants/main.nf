//
// A subworkflow to score and rank variants.
//

include { GENMOD_ANNOTATE } from '../../../modules/nf-core/genmod/annotate/main'
include { GENMOD_MODELS   } from '../../../modules/nf-core/genmod/models/main'
include { GENMOD_SCORE    } from '../../../modules/nf-core/genmod/score/main'
include { GENMOD_COMPOUND } from '../../../modules/nf-core/genmod/compound/main'
include { BCFTOOLS_VIEW   } from '../../../modules/nf-core/bcftools/view/main.nf'

workflow RANK_VARIANTS {
    take:
    ch_vcf                       // channel: [mandatory] [ val(meta), path(vcf) ]
    ch_ped                       // channel: [mandatory] [ val(meta), path(ped) ]
    ch_genmod_reduced_penetrance // channel: [mandatory] [ val(meta), path(penetrance) ]
    ch_score_config              // channel: [mandatory] [ val(meta), path(ini) ]
    val_score_only               // Boolean: [optional]  If true, only run the scoring step (i.e. skip annotation and model building)

    main:

    if (!val_score_only) {
    GENMOD_ANNOTATE(
        ch_vcf
    )

    GENMOD_ANNOTATE.out.vcf
        .join(ch_ped, failOnMismatch: true, failOnDuplicate: true)
        .set { genmod_models_in }

    GENMOD_MODELS(
        genmod_models_in,
        ch_genmod_reduced_penetrance .map { _meta, file -> file },
    )

    GENMOD_MODELS.out.vcf
        .join(ch_ped, failOnMismatch: true, failOnDuplicate: true)
        .set { genmod_score_in }

    }
    else {
        genmod_score_in = ch_vcf
            .combine(ch_score_config)
            .map { meta, vcf, score_config_meta, score_config ->
                tuple(meta, vcf, [], score_config)
            }
    }

    GENMOD_SCORE(
        genmod_score_in
    )


    if (!val_score_only) {
        GENMOD_COMPOUND(
            GENMOD_SCORE.out.vcf
        )

        bcftool_view_in = GENMOD_COMPOUND.out.vcf
            .map { meta, vcf ->
                tuple(meta, vcf, [])
            }
    }
    else {
        bcftool_view_in = GENMOD_SCORE.out.vcf
            .map { meta, vcf ->
                tuple(meta, vcf, [])
            }
    }

    BCFTOOLS_VIEW(
        bcftool_view_in,
        [],
        [],
        []
    )

    emit:
    vcf      = BCFTOOLS_VIEW.out.vcf // channel: [ val(meta), path(vcf) ]
    tbi      = BCFTOOLS_VIEW.out.tbi // channel: [ val(meta), path(tbi) ]
}
