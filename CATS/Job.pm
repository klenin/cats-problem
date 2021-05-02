package CATS::Job;

use strict;
use warnings;

use CATS::Constants;
use CATS::DB;

sub create_or_replace {
    my ($type, $fields) = @_;

    $dbh->selectrow_array(qq~
        SELECT COUNT(*) FROM jobs
        WHERE state = $cats::job_st_waiting AND type = $cats::job_type_submission AND
            req_id = ?~, undef,
        $fields->{req_id}) and return;

    cancel_all($fields->{req_id}) or return create($type, $fields) for (1..4);
    die;
}

sub is_canceled {
    my ($job_id) = @_;

    my ($st) = $dbh->selectrow_array(q~
        SELECT state FROM jobs WHERE id = ?~, undef,
        $job_id);

    $st == $cats::job_st_canceled;
}

sub cancel_all {
    my ($req_id) = @_;

    my $job_ids = $dbh->selectcol_arrayref(q~
        SELECT id FROM jobs WHERE finish_time IS NULL AND req_id = ?~, undef,
        $req_id);

    grep cancel($_), @$job_ids or $dbh->commit;
    @$job_ids;
}

sub cancel {
    my ($job_id) = @_;

    $dbh->do(q~
        DELETE FROM jobs_queue WHERE id = ?~, undef,
        $job_id);

    finish($job_id, $cats::job_st_canceled);
}

sub finish {
    my ($job_id, $job_state) = @_;

    my $finished;
    eval {
        $finished = ($dbh->do(q~
            UPDATE jobs SET state = ?, finish_time = CURRENT_TIMESTAMP
            WHERE id = ? AND finish_time IS NULL~, undef,
            $job_state, $job_id) // 0) > 0;
        $dbh->commit if $finished;
        1;
    } or return $CATS::DB::db->catch_deadlock_error('finish_job');
    $finished;
}

sub create {
    my ($type, $fields) = @_;

    $fields ||= {};
    $fields->{state} ||= $cats::job_st_waiting;
    my $job_id = new_id;

    $fields->{start_time} = \'CURRENT_TIMESTAMP' if $fields->{state} == $cats::job_st_in_progress;
    $dbh->do(_u $sql->insert('jobs', {
        %$fields,
        id => $job_id,
        type => $type,
        create_time => \'CURRENT_TIMESTAMP',
    })) or return;

    if ($fields->{state} == $cats::job_st_waiting) {
        $dbh->do(q~
            INSERT INTO jobs_queue (id) VALUES (?)~, undef,
            $job_id) or return;
    }

    $job_id;
}

sub create_splitted_jobs {
    my ($type, $testsets, $fields) = @_;

    $fields ||= {};
    $fields->{state} ||= $cats::job_st_waiting;

    is_canceled($fields->{parent_id}) and return;

    create($type, { %$fields, testsets => $_ }) for @$testsets;
}

1;
